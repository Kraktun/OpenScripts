import sys
import re
import sqlite3
import json
from datetime import datetime
import argparse


MANGADEX_BASE_API = "https://api.mangadex.org/manga"
THUMBNAIL = "https://i.imgur.com/6TrIues.jpg"
TACHIYOMI_DB = 'tachiyomi.db'
DATA_FILE = "mangadex_tc"
MANGADEX_DB = "mangadex.db" # from https://github.com/ivaniskandar/tachiyomi-mangadex-migrator/blob/main/app/src/main/assets/mangadex.db

def download(database):
    # to print special chars
    sys.stdout.reconfigure(encoding="utf-8")

    today = datetime.now()
    data_file = DATA_FILE + "_" + today.strftime("%y%m%d-%H%M%S") + ".json"

    con = sqlite3.connect(database)
    con.execute(f"ATTACH DATABASE '{MANGADEX_DB}' AS mangadexdb")
    cur = con.cursor()
    new_data = []

    # The source is mangadex 'en'
    # For the other languages see https://github.com/ivaniskandar/tachiyomi-mangadex-migrator/blob/02404d5f2d6f3aeeedf9a1a1160051490fc1ba0b/app/src/main/java/xyz/ivaniskandar/ayunda/MangaDexMigratorActivity.kt#L318
    total = cur.execute('SELECT COUNT(*) FROM mangas WHERE source=2499283573021220255 AND favorite=1').fetchall()[0][0]
    index = 0
    print(f"Total entries: {total}")
    # just one sql query
    for row in cur.execute("SELECT title, _id, url, replace(substr(url, 8), '/', '') AS common_id, manga.new_id FROM mangas LEFT JOIN mangadexdb.manga ON common_id = manga.legacy_id WHERE source=2499283573021220255 AND favorite=1"):
        index = index +1
        title = row[0]
        id = row[1] # this is the local tachiyomi id, not the old id of mangadex, so json are not reusable
        old_url = row[2]
        new_url = row[4]
        if re.search("\/(manga)\/[0-9]+\/?$", old_url) == None: 
            # already new format: skip
            continue
        
        new_data.append({
            "new_url": f'/manga/{new_url}', 
            "new_thumbnail": THUMBNAIL, 
            "id": id
        })

    con.close()

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
        new_data = [[x["new_url"], x["new_thumbnail"], x["id"]] for x in data]
        cur.executemany('UPDATE mangas SET url=?, thumbnail_url=? WHERE _id=?', new_data)
        con.commit()
    con.close()
    print("SUCCESS")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update link for mangadex following new API.')
    parser.add_argument('-l', '--load', type=str, help='Load the passed json fle overwriting the values in the database')
    parser.add_argument('-db', '--database', type=str, help='Specify tachiyomi database', default=TACHIYOMI_DB)

    args = parser.parse_args()
    if args.load is None:
        print(f"Started: {datetime.now()}")
        download(args.database)
        print(f"Completed: {datetime.now()}")
    else:
        load(args.load, args.database)