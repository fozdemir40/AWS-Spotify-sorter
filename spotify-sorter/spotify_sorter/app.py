from flask import Flask, request, render_template
from decouple import config
from spotipy import oauth2
import requests
import spotipy

app = Flask(__name__, template_folder='./templates')

SPOTIPY_CLIENT_ID = config('SPOTIPY_CLIENT_ID', default='')
SPOTIPY_CLIENT_SECRET = config('SPOTIPY_CLIENT_SECRET', default='')
SPOTIPY_REDIRECT_URI = 'http://127.0.0.1:5000/'
SCOPE = 'user-library-read user-library-modify playlist-modify-private'
CACHE = '.spotipyoauthcache'
sp_oauth = oauth2.SpotifyOAuth(SPOTIPY_CLIENT_ID, SPOTIPY_CLIENT_SECRET, SPOTIPY_REDIRECT_URI, scope=SCOPE,
                               cache_path=CACHE)

@app.route('/')
def index():
    access_token = ""

    token_info = sp_oauth.get_cached_token()

    if token_info:
        access_token = token_info['access_token']
    else:
        url = request.url
        code = sp_oauth.parse_response_code(url)
        if code != url:
            token_info = sp_oauth.get_access_token(code)
            access_token = token_info['access_token']

    if access_token:
        sp = spotipy.Spotify(access_token)
        results = sp.current_user_saved_tracks(limit=50, offset=0, market="NL")
        leftover_tracks = results['total'] - 50
        track_ids = []
        for i in results['items']:
            track_ids.append(i['track']['id'])
        return render_template('index.html', results=results, leftover_tracks=leftover_tracks, track_ids=track_ids)

    else:
        auth_url = get_spoauth_uri()
        return render_template('index.html', a_url=auth_url)


@app.route("/processing", methods=['POST'])
def process_tracks():
    token_info = sp_oauth.get_cached_token()

    aws_token = config('AWS_TOKEN', default='')
    aws_endpoint = config('AWS_ENDPOINT', default='')

    id_list = request.form.get('track_id_list')

    if id_list:
        for track_id in id_list:
            data = {'spotify_access_code': token_info, 'spotify_client_id': SPOTIPY_CLIENT_ID, 'track_id': track_id}
            headers = {'X-API-Key': config('AWS_TOKEN', default='')}
            response = requests.post(url=aws_endpoint, data=data, headers=headers)

            if response.status_code == 200:
                continue
            else:
                break
    else:
        return render_template('error_page.html')

    return render_template('process_tracks.html')


def get_spoauth_uri():
    auth_url = sp_oauth.get_authorize_url()
    return auth_url
