# Mini Storage Service

![Python 3.8](https://img.shields.io/badge/python-3.8-blue.svg)

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


## Deploying to Amazon Linux 2

AWS key pair is:

`KEYPAIR=$HOME/.ssh/miniss.pem`

EC2 instance is:

`HOST=Your-Instance`

App arguments are:

```sh
MINISS_META=.meta
MINISS_FORBIDDEN="Your-Forbidden-File1 Your-Forbidden-File2"
MINISS_USERNAME=Your-Username
MINISS_PASSWORD=Your-Password
```

Run this command in a shell prompt.

```bash
curl -fsSL https://raw.githubusercontent.com/oshinko/miniss/master/deploy-to-amazon-linux-2.sh \
    | sed -e "s/\$MINISS_META/$MINISS_META/" \
    | sed -e "s/\$MINISS_FORBIDDEN/$MINISS_FORBIDDEN/" \
    | sed -e "s/\$MINISS_USERNAME/$MINISS_USERNAME/" \
    | sed -e "s/\$MINISS_PASSWORD/$MINISS_PASSWORD/" \
    | ssh -i $KEYPAIR ec2-user@$HOST
```

When finished, open the form.
 
```bash
open http://$HOST/form.html
```
