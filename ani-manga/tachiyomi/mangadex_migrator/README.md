# README

## dex_migrate

Script used to migrate a tachiyomi database from the old mangadex API to the new one.  
It simply updates the old url with the new value provided by the included db.  
Does not require **root** access, but requires debug (aka beta) version of tachiyomi and adb debugging enabled (in developer options).  

To extract the db, from a command prompt

```(bash)
adb exec-out run-as eu.kanade.tachiyomi.debug cat databases/tachiyomi.db > tachiyomi.db
```

then run the python script

```(bash)
python dex_migrate.py
```

check that the matches are correct in the json file.  
Load the changes to the db (use the correct filename)

```(bash)
python dex_migrate.py -l mangadex_tc_xxxxx.json
```

Send the db to the device

```(bash)
adb push tachiyomi.db /data/local/tmp/tachiyomi.db
adb shell
run-as eu.kanade.tachiyomi.debug
cd databases
cp /data/local/tmp/tachiyomi.db .
exit
rm /data/local/tmp/tachiyomi.db
exit
```

### Notes

```mangadex.db``` is from [https://github.com/ivaniskandar/tachiyomi-mangadex-migrator/blob/main/app/src/main/assets/mangadex.db](https://github.com/ivaniskandar/tachiyomi-mangadex-migrator/blob/main/app/src/main/assets/mangadex.db)
There is no licence attached, so I assume it's public domain.

Chapter ids are not updated here, they are updated when you refresh the library (I don't know what happens with downloaded chapters).
