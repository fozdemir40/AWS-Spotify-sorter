from flask import Flask, request, render_template
from decouple import config
from spotipy import oauth2
import spotipy

app = Flask(__name__, template_folder='./templates')

SPOTIPY_CLIENT_ID = config('SPOTIPY_CLIENT_ID', default='')
SPOTIPY_CLIENT_SECRET = config('SPOTIPY_CLIENT_SECRET', default='')
SPOTIPY_REDIRECT_URI = 'http://127.0.0.1:5000/'
SCOPE = 'user-library-read ugc-image-upload'
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
        return render_template('index.html', results=results)

    else:
        auth_url = get_spoauth_uri()
        return render_template('index.html', a_url=auth_url)


@app.route("/processed", methods=['POST'])
def process_tracks():
    return render_template('process_tracks.html')


def get_spoauth_uri():
    auth_url = sp_oauth.get_authorize_url()
    return auth_url
