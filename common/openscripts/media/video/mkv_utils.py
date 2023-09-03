

def get_tracks_by_type(json_data: dict, track_type: str) -> list:
    return [tr for tr in json_data["tracks"] if tr["type"] == track_type]

def get_audio_tracks(json_data: dict) -> list:
    return get_tracks_by_type(json_data=json_data, track_type="audio")

def get_subtitle_tracks(json_data: dict) -> list:
    return get_tracks_by_type(json_data=json_data, track_type="subtitles")

def get_default_subs(subtitles_tracks):
    """
    Return a list of tuple (id, language) of the subtitles that are default tracks
    """
    return [(tr["id"], tr.get("properties", {}).get("language", None)) for tr in subtitles_tracks if tr.get("properties", {}).get("default_track", False)]

def get_forced_subs(subtitles_tracks: list[dict]) -> tuple | None:
    """
    Return a list of tuple (id, language) of the forced subtitle
    """
    return [(tr["id"], tr.get("properties", {}).get("language", None)) for tr in subtitles_tracks if tr.get("properties", {}).get("forced_track", False)]

def get_track_language(track: dict) -> str | None:
    return track.get("properties", {}).get("language", None)

def get_ietf_track_language(track: dict) -> str | None:
    return track.get("properties", {}).get("language_ietf", None)

def get_tracks_to_keep_by_lang(tracks: list, languages_blacklist: list | None = None, languages_whitelist: list | None = None, allow_none: bool = False):
    """
    Return the tracks in the list provided that have a valid language according to whitelist and blacklist.
    Only one between whitelist and blacklist must be specified.
    """

    assert (languages_blacklist and not languages_whitelist) or (languages_whitelist and not languages_blacklist), "Exactly one between language blacklist and whitelist must be defined"

    def has_good_language(track):
        def is_good(string_lang):
            if languages_whitelist:
                return string_lang in languages_whitelist
            else:
                return string_lang not in languages_blacklist
        lang = get_track_language(track)
        ietf_lang = get_ietf_track_language(track)
        if lang is None and ietf_lang is None:
            return allow_none
        elif lang is None:
            return is_good(ietf_lang)
        else:
            return is_good(lang)

    return [tr for tr in tracks if has_good_language(tr)]




