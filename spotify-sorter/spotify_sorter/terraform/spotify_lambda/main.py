import json
import spotipy
from os import getenv


def sorter(event, context):
        spotify_client_secret = getenv("spotify_client_secret")
        body = {
                "message": spotify_client_secret
        }

        return {"statusCode": 200, "body": json.dumps(body)}