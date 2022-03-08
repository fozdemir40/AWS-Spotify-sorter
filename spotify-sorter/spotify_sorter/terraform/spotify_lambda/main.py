import json
import spotipy


def sorter(event, context):
        body = {
                "message": "Hello Furkan"
        }

        return {"statusCode": 200, "body": json.dumps(body)}