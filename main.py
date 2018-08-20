import os
from fava.application import app
from fava.util import simple_wsgi
from werkzeug.wsgi import DispatcherMiddleware

app.config['BEANCOUNT_FILES'] = os.environ['BEANCOUNT_INPUT_FILE'].split(',')
prefix = os.environ['PREFIX']

if prefix:
    app.wsgi_app = DispatcherMiddleware(simple_wsgi, {prefix: app.wsgi_app})
