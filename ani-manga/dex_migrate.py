import requests
import sys
from difflib import SequenceMatcher
import time
import re
import sqlite3
import json
from datetime import datetime
import argparse
import os.path


MANGADEX_BASE_API = "https://api.mangadex.org/manga"
REGEX_REMOVE = "a|an|and|the"
THUMBNAIL = "https://i.imgur.com/6TrIues.jpg"
TIMER_BETWEEN_REQUESTS = 3
BATCH_SIZE = 10
WAIT_TIMER = 10
TACHIYOMI_DB = 'tachiyomi.db'
DATA_FILE = "mangadex_tc"
SKIP_FILE = "to_skip.txt"
MIN_DISTANCE = 0.7

def download(database, batch_size, min_distance):
    # to print special chars
    sys.stdout.reconfigure(encoding="utf-8")

    today = datetime.now()
    data_file = DATA_FILE + "_" + today.strftime("%y%m%d-%H%M%S") + ".json"

    con = sqlite3.connect(database)
    cur = con.cursor()
    new_data = []

    # to_skip keeps track of ids without a match, so it doesn't make sense to search them again
    # but if you want to try with a different regex or distance, you can remove them from the txt file 
    if os.path.isfile(SKIP_FILE):
        with open(SKIP_FILE) as f:
            to_skip = [int(x) for x in f.read().splitlines()]
    else:
        to_skip = []

    total = cur.execute('SELECT COUNT(*) FROM mangas WHERE source=2499283573021220255 AND favorite=1').fetchall()[0][0]
    index = 0
    print(f"Total entries: {total}")
    for row in cur.execute('SELECT title, _id, url FROM mangas WHERE source=2499283573021220255 AND favorite=1'):
        index = index +1
        title = row[0]
        id = row[1] # this is the local tachiyomi id, not the old id of mangadex, so json are not reusable
        url = row[2]
        if id in to_skip:
            # No Match from a previous iteration
            print(f"Ignoring {index}/{total}: {title}")
            continue

        if re.search("\/(manga)\/[0-9]+\/?$", url) == None: 
            # already new format: skip
            print(f"Skipping {index}/{total}: {title}")
            continue
        print(f"Processing {index}/{total}: {title}")
        processed_title = title.lower()
        # remove some special characters that give wrong results or no matches
        regex = re.compile(r"(\?|\\|\.|/|,)") # removed - ! ( )
        processed_title = regex.sub("", processed_title)
        # remove and, a, the etc. that give for some reason bad results
        processed_title = re.sub(f'\s+({REGEX_REMOVE})(\s+)', ' ', processed_title)
        done = False
        while not done:
            new_id, new_title, distance = process_manga(processed_title, min_distance)
            if new_id != None:
                # either no match or a match
                done = True
            else:
                # request errored, retry after 10 seconds
                print(f"Waiting {WAIT_TIMER} seconds...")
                time.sleep(WAIT_TIMER)
        if len(new_id) > 0:
            print(f"NEW TITLE {round(distance, 2)}: {new_title}")
            new_data.append({
                "source_title": title, # to manually check before loading in the db
                "new_title": new_title, 
                "new_url": f'/manga/{new_id}', 
                "new_thumbnail": THUMBNAIL, 
                "id": id
            })
        else:
            print("NO MATCH FOUND")
            to_skip.append(id)
        if len(new_data) >= batch_size:
            break

    con.close()

    # update skip file
    with open(SKIP_FILE, "w") as f:
        for item in to_skip:
            f.write("%s\n" % item)

    # write json file
    if len(new_data) > 0:
        with open(data_file, "w") as write_file:
            write_file.write(json.dumps(new_data, indent=4))


def load(data_file, database):
    with open(data_file, "r") as read_file:
        data = json.load(read_file)
    con = sqlite3.connect(database)
    cur = con.cursor()
    if len(data) > 0:
        # also update title and cover
        new_data = [[x["new_url"], x["new_title"], x["new_thumbnail"], x["id"]] for x in data]
        cur.executemany('UPDATE mangas SET url=?, title=?, thumbnail_url=? WHERE _id=?', new_data)
        con.commit()
    con.close()
    print("SUCCESS")


def process_manga(source_title, min_distance, print_info=False):

    # sleep to avoid too many requests
    time.sleep(TIMER_BETWEEN_REQUESTS)

    if print_info: print(f"Processing '{source_title}'")

    parameters = {
        "limit": 10,
        "title": source_title
    }

    try :
        response = requests.get(MANGADEX_BASE_API, params=parameters)
    except:
        # timeout
        print("Error. Retrying...")
        return None, None, None

    res_code = response.status_code

    if res_code != 200:
        if res_code == 204:
            print("No content found")
            return "", "", -1
        else:
            print(f"Error: {response}")
        return None, None, None

    data = response.json()

    best_match_distance = min_distance # set a min value
    best_match_title = ""
    best_match_id = ""
    orig_title = ""
    results = data["results"]

    for manga in results:
        id = manga["data"]["id"]
        titles = manga["data"]["attributes"]
        t_en = titles["title"]["en"]
        dist = SequenceMatcher(None, source_title, t_en).ratio()
        if dist > best_match_distance:
            best_match_distance = dist
            best_match_title = t_en
            best_match_id = id
            orig_title = t_en
            if print_info: print(f"Current best title: {t_en}")
        t_alts = titles["altTitles"] # search also among alternative titles in case it was updated
        for alt_title in t_alts:
            en_alt = alt_title["en"]
            if dist > best_match_distance:
                best_match_distance = dist
                best_match_title = en_alt
                best_match_id = id
                if print_info: print(f"Current best title: {t_en}")
        
    if print_info: print(f"Final match:\n\t{source_title} -> {best_match_title}\n\twith score: {best_match_distance}")
    return best_match_id, orig_title, best_match_distance



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update link for mangadex following new API.')
    parser.add_argument('-l', '--load', type=str, help='Load the passed json fle overwriting the values in the database')
    parser.add_argument('-db', '--database', type=str, help='Specify tachiyomi database', default=TACHIYOMI_DB)
    parser.add_argument('-b', '--batch', type=int, help='Specify batch size', default=BATCH_SIZE)
    parser.add_argument('-d', '--distance', type=float, help='Specify minimum distance between titles', default=MIN_DISTANCE)

    args = parser.parse_args()
    if args.load is None:
        print(f"Started: {datetime.now()}")
        download(args.database, args.batch, args.distance)
        print(f"Completed: {datetime.now()}")
    else:
        load(args.load, args.database)