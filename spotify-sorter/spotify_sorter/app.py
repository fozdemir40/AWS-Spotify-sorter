from flask import Flask, request, render_template
from spotipy import oauth2
import spotipy

app = Flask(__name__, template_folder='./templates')

SPOTIPY_CLIENT_ID = ''
SPOTIPY_CLIENT_SECRET = ''
SPOTIPY_REDIRECT_URI = 'http://127.0.0.1:5000/'
SCOPE = 'user-library-read'
CACHE = '.spotipyoauthcache'
sp_oauth = oauth2.SpotifyOAuth(SPOTIPY_CLIENT_ID, SPOTIPY_CLIENT_SECRET, SPOTIPY_REDIRECT_URI, scope=SCOPE,
                               cache_path=CACHE)

app.route('/')
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
        results = sp.current_user()
        return results

    else:
        return login_view()


def login_view():
    auth_url = get_spoauth_uri()
    return render_template('index.html', a_url=auth_url)


def get_spoauth_uri():
    auth_url = sp_oauth.get_authorize_url()
    return auth_url
