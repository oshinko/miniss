import base64
import cgi
import json
import os
import pathlib
import random
import string
import sys
import wsgiref.simple_server

default_meta = '.meta'
default_headers = [('Access-Control-Allow-Origin', '*')]

statuses = {int(x.split(maxsplit=1)[0]): x.split(maxsplit=1)[1] for x in """
200 OK
302 Found
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
405 Method Not Allowed
""".strip().splitlines()}

workspace = pathlib.Path.cwd()


def _respond(respond, status, headers=None):
    respond(f'{status} {statuses[status]}', default_headers + (headers or []))


def _assert_owner(environ, username, password):
    auth = environ.get('HTTP_AUTHORIZATION')
    assert auth and 'Basic' in auth
    b64a = auth.replace('Basic', '').strip().rstrip('=')
    b64b = base64.b64encode(f'{username}:{password}'.encode())
    assert b64a == b64b.decode().rstrip('=')


def _random_filename():
    s = string.ascii_uppercase + string.ascii_lowercase + string.digits
    return ''.join(random.choices(s, k=16))


def app(environ, respond):
    _meta = pathlib.Path(os.environ.get('MINISS_META') or default_meta)
    _forbidden = os.environ.get('MINISS_FORBIDDEN', '').split()
    username = os.environ.get('MINISS_USERNAME', '')
    password = os.environ.get('MINISS_PASSWORD', '')
    if not _meta.is_absolute():
        meta = workspace / _meta
    meta.mkdir(parents=True, exist_ok=True)
    forbidden = set([meta])
    for path in _forbidden:
        p = pathlib.Path(path)
        if not p.is_absolute():
            p = workspace / p
        forbidden.add(p)
    without_leading_slash = environ['PATH_INFO'][1:]
    path = workspace / without_leading_slash
    if path in forbidden:
        _respond(respond, 403)
        return []
    meta /= without_leading_slash
    method = environ['REQUEST_METHOD']
    if method == 'DELETE':
        if not path.is_file():
            _respond(respond, 404)
            return []
        if username or password:
            try:
                _assert_owner(environ, username, password)
            except Exception:
                _respond(respond, 401, [('WWW-Authenticate', 'Basic')])
                return []
        meta.unlink()
        path.unlink()
        _respond(respond, 200, [('Content-Type', 'text/plain')])
        return []
    elif method in ('GET', 'HEAD'):
        if not path.exists():
            _respond(respond, 404)
            return []
        if path.is_dir():
            if username or password:
                try:
                    _assert_owner(environ, username, password)
                except Exception:
                    _respond(respond, 401, [('WWW-Authenticate', 'Basic')])
                    return []
            index = path / 'index.html'
            if index.is_file():
                _respond(respond, 200, [('Content-Type', 'text/html')])
                return [index.read_bytes()] if method == 'GET' else []
            _respond(respond, 200)
            objs = (f'{x.relative_to(workspace)}\n'.encode()
                    for x in path.glob('**/*') if str(_meta) not in str(x))
            return objs if method == 'GET' else []
        metadata = json.loads(meta.read_text()) if meta.is_file() else {}
        u = metadata.get('username', '')
        p = metadata.get('password', '')
        if u or p:
            auth = environ.get('HTTP_AUTHORIZATION')
            if auth and 'Basic' in auth:
                b64a = auth.replace('Basic', '').strip().rstrip('=')
                b64b = base64.b64encode(f'{u}:{p}'.encode())
                if b64a != b64b.decode().rstrip('='):
                    _respond(respond, 401, [('WWW-Authenticate', 'Basic')])
                    return []
            else:
                _respond(respond, 401, [('WWW-Authenticate', 'Basic')])
                return []
        status = metadata.get('status', 200)
        headers = [(k, v) for k, v in metadata.get('headers', [])]
        _respond(respond, status, headers)
        return [path.read_bytes()] if method == 'GET' else []
    elif method == 'OPTIONS':
        allow_methods = 'DELETE GET OPTIONS POST PUT'.split()
        _respond(respond, 200, [('Allow', ', '.join(allow_methods)),
                                ('Access-Control-Allow-Methods',
                                 ', '.join(allow_methods)),
                                ('Access-Control-Allow-Headers',
                                 'Authorization')])
        return []
    elif method in ['POST', 'PUT']:
        if method == 'POST':
            for _ in range(8):
                new_filename = _random_filename()
                meta /= new_filename
                path /= new_filename
                if not path.exists():
                    break
            else:
                raise Exception('file creation failed')
        if username or password:
            try:
                _assert_owner(environ, username, password)
            except Exception:
                _respond(respond, 401, [('WWW-Authenticate', 'Basic')])
                return []
        u = p = link = data = None
        if (environ['CONTENT_TYPE'] == 'application/x-www-form-urlencoded'
                or 'multipart/form-data' in environ['CONTENT_TYPE']):
            form = cgi.FieldStorage(fp=environ['wsgi.input'], environ=environ)
            form = {k: form[k].value for k in form}
            u = form.get('username', form.get('user', form.get('userid')))
            p = form.get('password', form.get('pass', form.get('passwd')))
            link = form.get('link', form.get('ref', form.get('to')))
            data = form.get('data', '').encode() or form.get('file', b'')
        else:
            content_length = int(environ.get('CONTENT_LENGTH', 0))
            data = environ['wsgi.input'].read(content_length)
        metadata = {}
        if link:
            metadata['status'] = 302
            metadata['headers'] = [('Location', link)]
        if u:
            metadata['username'] = u
        if p:
            metadata['password'] = p
        meta.parent.mkdir(parents=True, exist_ok=True)
        meta.write_text(json.dumps(metadata) + '\n')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        _respond(respond, 200, [('Content-Type', 'text/plain')])
        return [str(path.relative_to(workspace)).encode()]
    else:
        _respond(respond, 405)
        return []


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    httpd = wsgiref.simple_server.make_server('', port, app)
    print(f'Serving {workspace} on port {port}, control-C to stop')
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('Shutting down.')
        httpd.server_close()
