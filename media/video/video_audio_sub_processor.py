import click
import json

from pathlib import Path

from openscripts.io import process_utils
from openscripts.media.video.mkv_utils import (
    get_default_subs,
    get_forced_subs,
    get_audio_tracks,
    get_subtitle_tracks,
    get_tracks_to_keep_by_lang,
    get_track_language,
    get_ietf_track_language
)
from openscripts.io.file_utils import human_readable

# TODO: make a proper wrapper for all fields returned by mkvmerge
# todo: add choice for sub based on tags (i.e. prefix of sub, or string contains)

@click.command()
@click.option(
    "--input-folder",
    type=str,
    required=True
)
@click.option(
    "--include-subdirs",
    is_flag=True
)
@click.option(
    "--language-audio-blacklist",
    "--lang-audio-out",
    type=str,
    multiple=True,
)
@click.option(
    "--language-audio-whitelist",
    "--lang-audio-in",
    type=str,
    multiple=True,
)
@click.option(
    "--language-audio-blacklist",
    "--lang-audio-out",
    type=str,
    multiple=True,
)
@click.option(
    "--language-audio-whitelist",
    "--lang-audio-in",
    type=str,
    multiple=True,
)
@click.option(
    "--extensions-whitelist",
    type=str,
    multiple=True,
    default=["mkv"]
)
@click.option(
    "--default-audio-lang",
    type=str
)
@click.option(
    "--default-sub-lang",
    type=str
)
@click.option(
    "--disable-sub-processing",
    is_flag=True
)
@click.option(
    "--sub-choice-selector",
    type=click.Choice(['max_size', 'min_size']),
    default="max_size"
)
@click.option(
    "--dry-run",
    is_flag=True
)
@click.option(
    "--tmp-folder",
    type=str
)
@click.option(
    "--auto-confirm",
    is_flag=True
)
def main(input_folder, include_subdirs, language_audio_blacklist, language_audio_whitelist, extensions_whitelist, default_audio_lang, default_sub_lang, disable_sub_processing, sub_choice_selector, dry_run, tmp_folder, auto_confirm):
    input_folder = Path(input_folder)
    assert input_folder.exists(), "Input folder does not exist"
    extensions_whitelist = [ext.lstrip('.') for ext in extensions_whitelist]
    assert (language_audio_blacklist and not language_audio_whitelist) or (language_audio_whitelist and not language_audio_blacklist), "Only one between language blacklist and whitelist must be chosen for audio"
    assert not default_audio_lang or (language_audio_whitelist and default_audio_lang in language_audio_whitelist) or (language_audio_blacklist and default_audio_lang not in language_audio_blacklist), "You chose as default a language that you want to remove"

    if include_subdirs:
        glob_prefix = "**/*"
    else:
        glob_prefix = "*"

    for ext in extensions_whitelist:
        target_files = list(input_folder.glob(f"{glob_prefix}.{ext}"))
        files_len = len(target_files)
        for index, target_file in enumerate(target_files, start=1):
            file_dir = target_file.parent
            # todo: use a proper temp file
            if not tmp_folder:
                tmp_folder = file_dir
            else:
                tmp_folder = Path(tmp_folder)
                tmp_folder.mkdir(parents=True, exist_ok=True)
            tmp_file = tmp_folder / f"tmp_some_random_chars.{ext}"
            print(f"[{index}/{files_len}]\n> Analyzing {target_file.name} [{human_readable(target_file.stat().st_size)}]")

            # get audio languages
            file_info = process_utils.execute_command(["mkvmerge", "-J", str(target_file)], return_output=True, silent=True)
            file_info = json.loads(file_info)
            audio_tracks = get_audio_tracks(file_info)
            subtitles_tracks = get_subtitle_tracks(file_info)
            audio_ids_to_keep = [str(tr['id']) for tr in get_tracks_to_keep_by_lang(tracks=audio_tracks, languages_blacklist=language_audio_blacklist, languages_whitelist=language_audio_whitelist, allow_none=True)]
            has_languages_to_remove = len(audio_ids_to_keep) < len(audio_tracks)
            
            # create map uid -> id 
            # the uid is used by e.g. mediainfo
            # the id by mkvmerge
            id_map = {}
            def attach_id_map(tracks):
                for tr in tracks:
                    id = tr["id"]
                    uid = tr.get("properties", {})["uid"]
                    id_map[str(uid)] = id
            attach_id_map(audio_tracks)
            attach_id_map(subtitles_tracks)


            audio_arguments = []
            print(f">> Found {len(audio_tracks) - len(audio_ids_to_keep)}/{len(audio_tracks)} audio tracks to remove.")

            if len(audio_tracks) > 1:
                if has_languages_to_remove and len(audio_ids_to_keep) > 0:
                    
                    audio_ids_to_keep = ",".join(audio_ids_to_keep)
                    audio_arguments += ["-a", audio_ids_to_keep]
                elif has_languages_to_remove:
                    print("WARNING: ALL LANGUAGES WOULD BE REMOVED. SKIPPING AUDIO REMOVAL.")
                
                if default_audio_lang:
                    # set all audio tracks with target the default lang as default
                    audio_tracks_to_default = [str(tr["id"]) for tr in audio_tracks if str(tr["id"]) in audio_ids_to_keep and (get_track_language(tr) == default_audio_lang or get_ietf_track_language(tr) == default_audio_lang)]
                    for def_audio in audio_tracks_to_default:
                        audio_arguments += ["--default-track-flag", def_audio]
            else:
                print(">> Only one audio track, skipping audio processing.")

            def get_media_info_sub_data():
                mediainfo_data = process_utils.execute_command(["mediainfo", "--Output=JSON", str(target_file)], return_output=True, silent=True)
                mediainfo_data = json.loads(mediainfo_data)
                tracks = mediainfo_data.get("media", {}).get("track",[])
                sub_tracks = [(id_map[tr["UniqueID"]], tr["StreamSize"]) for tr in tracks if tr["@type"] == "Text"]
                return sub_tracks

            def is_better_sub(current_best_size, candidate_best_size):
                return (
                    (sub_choice_selector == "max_size" and candidate_best_size > current_best_size) or
                    (sub_choice_selector == "min_size" and candidate_best_size < current_best_size)
                )

            # process subs
            subs_arguments = []

            if not disable_sub_processing and len(subtitles_tracks) > 1:
                
                if default_sub_lang:
                    target_subs = get_tracks_to_keep_by_lang(tracks=subtitles_tracks, languages_whitelist=[default_sub_lang])
                    # get current default and forced, to disable them
                    default_subs = get_default_subs(subtitles_tracks)
                    default_subs_ids = [subb[0] for subb in default_subs]
                    forced_subs = get_forced_subs(subtitles_tracks)
                    forced_subs_ids = [subb[0] for subb in forced_subs]
                    
                    sub_to_default = None

                    if len(target_subs) == 1:
                        print(">> Found sub with target language")
                        sub_to_default = target_subs[0]["id"]
                    
                    elif len(target_subs) > 1:
                        print(">> Found multiple subs with target language")
                        subs_sizes = get_media_info_sub_data()
                        subs_sizes = dict(subs_sizes)
                        # pick the one with biggest size
                        sub_to_default = target_subs[0]["id"]
                        target_sub_size = -1
                        for s in target_subs:
                            s_size = int(subs_sizes.get(s["id"], -1))
                            if is_better_sub(target_sub_size, s_size):
                                sub_to_default = s["id"]
                                target_sub_size = s_size
                    
                    else:
                        print(f">> No sub found with target language [{default_sub_lang}]. Skipping sub processing.")
                        available_langs = list(set([track.get("properties", {}).get("language", None) for track in subtitles_tracks]))
                        print(f"Available languages are: {available_langs}")
                    
                    if sub_to_default:
                        for s_id in default_subs_ids:
                            if s_id != sub_to_default:
                                subs_arguments += ["--default-track-flag", f"{s_id}:0"]
                        if sub_to_default not in default_subs_ids:
                            # add default track only if there are other subs and it's not already default
                            subs_arguments += ["--default-track-flag", sub_to_default]
                        else:
                            print(">> New default sub = current default. Not adding new default track.")
                    if forced_subs_ids:
                        for s_id in forced_subs_ids:
                            if s_id != sub_to_default:
                                # remove old forced subs
                                subs_arguments += ["--forced-display-flag", f"{s_id}:0"]
            elif not disable_sub_processing:
                print("Only one sub track. Skipping sub processing.")

            append_arguments = audio_arguments + subs_arguments
            append_arguments = [str(chunk) for chunk in append_arguments]

            if dry_run and append_arguments:
                print("[DRY RUN] Would execute")
                print(f'{" ".join(["mkvmerge", "-o", str(tmp_file)] + append_arguments + [str(target_file)])}')
            elif dry_run:
                print("[DRY RUN] Would not process anything")
            elif append_arguments:
                print(">> Command to execute")
                print(f'{" ".join(["mkvmerge", "-o", str(tmp_file)] + append_arguments + [str(target_file)])}')
                if not auto_confirm:
                    input("\n>>>\tPress Enter to continue...")
                print(">>> PROCESSING...")
                process_utils.execute_command(["mkvmerge", "-o", str(tmp_file)] + append_arguments + [target_file], silent=True)
                target_file.unlink()
                tmp_file.rename(target_file)
            print()
            
                
                


if __name__ == "__main__":
    # usage e.g. python remove_lang_audio.py --input-folder "path/to/my/folder" --include-subdirs --lang-audio-out "eng" --lang-audio-out "spa" --default-sub-lang "eng"
    main()
