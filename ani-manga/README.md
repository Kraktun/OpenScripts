# README

## dex_migrate

Script used to migrate a tachiyomi database from the old mangadex API to the new one.  
It simply updates the old url with the new values by searching each manga.  
Requires **root** access.  

To extract the db, from a command prompt

```(bash)
adb exec-out run-as eu.kanade.tachiyomi.debug cat databases/tachiyomi.db > tachiyomi.db
```

then run the python script (e.g. with the first 100 successfull matches)

```(bash)
python dex_migrate.py -b 100
```

check that the matches are correct in the json file.  
Load the changes to the db (use the correct filename)

```(bash)
python dex_migrate.py -l mangadex_tc_xxxxx.json
```

Send the db to the device (requires root)

```(bash)
adb push tachiyomi.db /data/local/tmp/tachiyomi.db
adb shell
su
cp /data/local/tmp/tachiyomi.db /data/data/eu.kanade.tachiyomi.debug/databases/tachiyomi.db
rm /data/local/tmp/tachiyomi.db
```

You can parse different batches of manga, but you have to load the results to the db (or add the ids to the skip list) because the download function reads always from the database.  
(I.e. after each ```python dex_migrate.py``` without ```-l``` you must run a ```python dex_migrate.py -l mangadex_tc_xxxxx.json```)

### Notes

Manga with a short name almost always fail.  
I suggest to keep a high distance for the first pass (0.7 or 0.8). For my library (about 600 entries) around 90% are correct, and 10% a miss (2 were wrong).  
Then use a second pass with a low distance (0.5) and manually check to avoid wrong results.
