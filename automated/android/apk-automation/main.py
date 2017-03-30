from argparse import ArgumentParser
import importlib

parser = ArgumentParser()
parser.add_argument('-d', '--apk_dir', dest='apk_dir', default='./apks',
                    help="Specify APK's directory.")
parser.add_argument('-u', '--base_url', dest='base_url', default='http://testdata.validation.linaro.org/apks/',
                    help="Specify APK's base url.")
parser.add_argument('-n', '--name', dest='name', default='linpack',
                    help='Specify test name.')
parser.add_argument('-l', '--loops', type=int, dest='loops', default=1,
                    help='Set the number of test loops.')
parser.add_argument('-v', '--verbose', action='store_true', dest='verbose',
                    default=False, help='Set the number of test loops.')
args = parser.parse_args()
print('Test job arguments: %s' % args)

config = vars(args)
mod = importlib.import_module(config['name'])
a = mod.ApkRunnerImpl(config)
a.run()
