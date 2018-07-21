import os
from fava.application import app

app.config['BEANCOUNT_FILES'] = os.environ['BEANCOUNT_INPUT_FILE'].split(',')
