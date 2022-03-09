import json
import spotipy


def sorter(event, context):
    sp = spotipy.Spotify(event['spotify_access_code'])
    track_id = event['track_id']

    tracks = [track_id]

    track_result = sp.audio_features(tracks=track_id)
    track_energy = track_result[0]['energy']

    high_energy_playlist_id = '3JXnToNrDLdnQePaf6uAwe'
    mid_energy_playlist_id = '2nTV7XzNHeNuU89P8tncJa'
    low_energy_playlist_id = '028eOwGowmSs3atL0Ivz35'

    add_response = None
    energy_type = ""

    if track_energy < 0.4:
        energy_type = "Low"
        add_response = sp.playlist_add_items(low_energy_playlist_id, tracks)  # Low energy track
    elif track_energy > 0.6:
        energy_type = "High"
        add_response = sp.playlist_add_items(high_energy_playlist_id, tracks)  # High energy track
    else:
        energy_type = "Mid"
        add_response = sp.playlist_add_items(mid_energy_playlist_id, tracks)  # Mid-energy track

    if add_response['snapshot_id']:
        remove_response = sp.current_user_saved_tracks_delete(tracks)

        body = {
                "message": f"Track successfully sorted to '{energy_type} Energy' playlist!"
        }

        return {"statusCode": 200, "body": json.dumps(body)}

    else:
        body = {
            "message": "Something went wrong with Spotify API"
        }

        return {"statusCode": 500, "body": json.dumps(body)}



