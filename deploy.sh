if [ -z "$TEMP" ] || [ ! -d $TEMP ]; then
  echo "No such directory \"$TEMP\""
fi

# Cleanup temporaries
rm -rf $TEMP/miniss-*

# Setup easy deployment scripts
git clone https://github.com/oshinko/ops.git -b 0.0.0 $TEMP/miniss-ops
OPS=$TEMP/miniss-ops/src

# Create file of the app's environment variables
ENVIRONMENT_FILE=$TEMP/miniss-env
cat << EOS > $ENVIRONMENT_FILE
MINISS_META=$MINISS_META
MINISS_FORBIDDEN="$MINISS_FORBIDDEN"
MINISS_USERNAME=$MINISS_USERNAME
MINISS_PASSWORD=$MINISS_PASSWORD
EOS

# Deployment
REMOTE=$REMOTE \
KEYPAIR=$KEYPAIR \
SERVER=$SERVER \
PORT=$PORT \
PACKAGE=git+https://github.com/oshinko/miniss.git \
DESCRIPTION="Mini Storage Service" \
APP=miniss:app \
ENVIRONMENT_FILE=$ENVIRONMENT_FILE \
sh $OPS/update-nginx-wsgi.sh

# Create form
cat << EOF > $TEMP/miniss-form.html
<!DOCTYPE html>
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
curl -X PUT \
     -u $MINISS_USERNAME:$MINISS_PASSWORD \
     -F file=@$TEMP/miniss-form.html \
     http://$SERVER/form.html
