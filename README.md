# Mini Storage Service

![Python 3.9](https://img.shields.io/badge/python-3.9-blue.svg)

This is a mutable URL shortener and very simple web storage service.


## Installation

`pip install -U git+https://github.com/oshinko/miniss.git`


## Running server

`python -m miniss`

To customize the port number:

`python -m miniss 8888`

To pass environment variables:

`MINISS_META=/path/to/meta python -m miniss`


## Usage

To put a text object:

`curl -X PUT -d data=Hello! http://localhost:8000/Your-Text-Object`

To put a link object:

`curl -X PUT -d link=https://www.example.com http://localhost:8000/Your-Link-Object`

To authenticate the object creator:

```sh
curl -X PUT \
     -u Your-Username:Your-Password \
     -d link=https://www.example.com \
     http://localhost:8000/Your-Link-Object
```

To get a object:

`curl http://localhost:8000/Your-Text-Object`

To create a secret object:

```sh
curl -X PUT \
     -d data=Hello! \
     -d user=Your-Family \
     -d pass=Your-Family-Password \
     http://localhost:8000/Your-Text-Object
```

To get a secret object:

`curl -u Your-Family:Your-Family-Password http://localhost:8000/Your-Text-Object`


# Deployment to Linux server

Set SSH remote destination, e.g. `ec2-user@example.com`:

`REMOTE=Your-Instance`

SSH key pair is:

`KEYPAIR=$HOME/.ssh/miniss.pem`

Set server name, e.g. `miniss.example.com`:

`SERVER=Your-Server-Name`

Set server port:

`PORT=80`

Set temporary directory, e.g. `/tmp`:

```sh
if [ -z "$TEMP" ]; then
  TEMP=Your-Temporary-Directory-Path
fi
```

App arguments are:

```sh
MINISS_META=.meta
MINISS_FORBIDDEN="Your-Forbidden-File1 Your-Forbidden-File2"
MINISS_USERNAME=Your-Username
MINISS_PASSWORD=Your-Password
```

Run this command in a shell prompt:

```sh
curl -fsSL https://raw.githubusercontent.com/oshinko/miniss/master/deploy.sh \
  | REMOTE=$REMOTE \
    KEYPAIR=$KEYPAIR \
    SERVER=$SERVER \
    PORT=$PORT \
    TEMP=$TEMP \
    MINISS_META=$MINISS_META \
    MINISS_FORBIDDEN=$MINISS_FORBIDDEN \
    MINISS_USERNAME=$MINISS_USERNAME \
    MINISS_PASSWORD=$MINISS_PASSWORD \
    sh
```

When finished, open the form:

`python -m webbrowser -t http://$SERVER/form.html`
