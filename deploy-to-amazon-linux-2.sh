# Python
sudo yum install python3 -y
python3 -m venv .venv

# Gunicorn
.venv/bin/python -m pip install -U gunicorn

# Git
sudo yum install git -y

# App
.venv/bin/python -m pip install -U pip git+https://github.com/oshinko/miniss.git
mkdir -p miniss
sudo bash -c "cat << EOF > /etc/systemd/system/miniss.service
[Unit]
Description=Mini Storage Service

[Service]
Environment=MINISS_META=$MINISS_META
Environment=\"MINISS_FORBIDDEN=$MINISS_FORBIDDEN\"
Environment=MINISS_USERNAME=$MINISS_USERNAME
Environment=MINISS_PASSWORD=$MINISS_PASSWORD
WorkingDirectory=/home/ec2-user/miniss
ExecStart=/home/ec2-user/.venv/bin/gunicorn miniss:app --bind unix:/home/ec2-user/gunicorn.sock
Restart=always
Type=simple
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF"
sudo systemctl daemon-reload
sudo systemctl enable miniss.service
sudo systemctl restart miniss.service

# Nginx
sudo amazon-linux-extras install nginx1.12 -y
sudo bash -c "cat << 'EOF' > /etc/nginx/nginx.conf
# ref: https://github.com/benoitc/gunicorn/blob/master/examples/nginx.conf
worker_processes 1;

user nginx nginx;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
  worker_connections 1024; # increase if you have lots of clients
  accept_mutex off; # set to 'on' if nginx worker_processes > 1
  use epoll;
}

http {
  include mime.types;
  default_type application/octet-stream;
  access_log /var/log/nginx/access.log combined;
  sendfile on;

  upstream app_server {
    server unix:/home/ec2-user/gunicorn.sock fail_timeout=0;
  }

  server {
    listen 80 default_server deferred;
    client_max_body_size 4G;

    keepalive_timeout 5;

    location / {
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header Host \$http_host;
      proxy_redirect off;
      proxy_pass http://app_server;
    }
  }
}
EOF"
sudo usermod -aG nginx ec2-user
sudo chgrp nginx $HOME
sudo chmod g+x $HOME
sudo systemctl enable nginx.service
sudo systemctl start nginx.service

# Form
cat << EOF > form.html
<!doctype html>
<html>
<head>
  <title>Mini Storage Service</title>
  <style>
    pre {
      margin: 2em 2px 2px 2px;
      padding: .5em;
      width: 98%;
      height: 8em;
      overflow: scroll;
      border: 1px solid gray;
    }
  </style>
</head>
<body>
  <h1>Mini Storage Service</h1>
  <form action="/">
    <fieldset>
      <legend>HTTP Method</legend>
      <select></select>
    </fieldset>
    <fieldset>
      <legend>Authentication</legend>
      <input type="text" placeholder="Username"><br>
      <input type="password" placeholder="Password">
    </fieldset>
    <fieldset>
        <legend>Object Key</legend>
        <input type="text" placeholder="Object Key">
    </fieldset>
    <fieldset>
      <legend>Metadata</legend>
      <input type="text" name="user" placeholder="Object Username"><br>
      <input type="password" name="pass" placeholder="Object Password"><br>
      <input type="text" name="link" placeholder="Link">
    </fieldset>
    <fieldset>
      <legend>Data</legend>
      <input type="text" name="data" placeholder="Text"><br>
      <input type="file" name="file">
    </fieldset>
    <input type="submit" value="Submit">
  </form>
  <pre></pre>
  <button>Select ALL</button>
  <script>
    var form = document.querySelector('form');
    var base = form.action.replace(/\/*$/, '');
    var method = document.querySelector('select');
    var key = document.querySelector('input[placeholder="Object Key"]');
    var username = document.querySelector('input[placeholder="Username"]')
    var password = document.querySelector('input[placeholder="Password"]')
    var submit = document.querySelector('input[type=submit]');
    var display = document.querySelector('pre');
    var button = document.querySelector('button');
    var data;
    var createHttpMethodElement = (method, selected) => {
      let element = document.createElement('option');
      element.selected = selected;
      element.innerText = method;
      return element;
    };
    var refresh = ev => {
      form.action = base + '/' + key.value;
      data = new FormData(form);
      if (ev && ev.target && ev.target == method) {
        // When change a HTTP method
        return;
      }
      Array.from(method.children).forEach(x => method.removeChild(x));
      if (key.value) {
        if (data.get('link') || data.get('data') || data.get('file').name) {
          if (key.value.endsWith('/')) {
            method.add(createHttpMethodElement('POST'));
          } else {
            method.add(createHttpMethodElement('PUT'));
          }
        } else {
          method.add(createHttpMethodElement('DELETE'));
          method.add(createHttpMethodElement('GET', true));
        }
      } else {
        method.add(createHttpMethodElement('GET'));
      }
    };
    refresh();
    form.addEventListener('change', refresh);
    form.addEventListener('submit', ev => {
      data = new FormData(form);
      let methodVal = method.selectedOptions[0].value;
      let req = new XMLHttpRequest();
      req.open(methodVal, form.action);
      if (username.value || password.value) {
        let auth = 'Basic ' + btoa(username.value + ':' + password.value);
        req.setRequestHeader('Authorization', auth);
      }
      req.onload = () => {
        display.innerText = req.responseText;
        console.log(req.responseText)
        if (req.status != 200) {
          display.innerText += '\n' + req.status + ' ' + req.statusText;
          console.error(req.status + ' ' + req.statusText);
        }
      };
      req.onerror = () => {
        display.innerText = req.statusText || 'Network error';
        console.error(req.statusText || 'Network error');
      };
      req.send(['POST', 'PUT'].includes(methodVal) ? data : null);
      ev.preventDefault();
    });
    button.addEventListener('click', () => {
      if (window.getSelection) {
        var range = document.createRange();
        range.selectNode(display);
        window.getSelection().removeAllRanges();
        window.getSelection().addRange(range);
      }
    });
  </script>
</body>
</html>
EOF
curl -X PUT -u $MINISS_USERNAME:$MINISS_PASSWORD -F file=@form.html http://localhost/form.html
rm form.html
