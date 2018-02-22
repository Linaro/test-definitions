import collections
import os
import subprocess
import yaml
from argparse import ArgumentParser
from csv import DictWriter
from jinja2 import Environment, FileSystemLoader


class PrependOrderedDict(collections.OrderedDict):

    def prepend(self, key, value, dict_setitem=dict.__setitem__):

        root = self._OrderedDict__root
        first = root[1]

        if key in self:
            link = self._OrderedDict__map[key]
            link_prev, link_next, _ = link
            link_prev[1] = link_next
            link_next[0] = link_prev
            link[0] = root
            link[1] = first
            root[1] = first[0] = link
        else:
            root[1] = first[0] = self._OrderedDict__map[key] = [root, first, key]
            dict_setitem(self, key, value)


def render(obj, template="testplan.html", name=None):
    if name is None:
        name = template
    templates_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "templates")
    _env = Environment(loader=FileSystemLoader(templates_dir))
    _template = _env.get_template(template)
    _obj = _template.render(obj=obj)
    with open("{}".format(name), "wb") as _file:
        _file.write(_obj.encode('utf-8'))


# get list of repositories and cache them
def repository_list(testplan):
    repositories = set()
    tp_version = testplan['metadata']['format']
    if tp_version == "Linaro Test Plan v2":
        if 'manual' in testplan['tests'].keys() and testplan['tests']['manual'] is not None:
            for test in testplan['tests']['manual']:
                repositories.add(test['repository'])

        if 'automated' in testplan['tests'].keys() and testplan['tests']['automated'] is not None:
            for test in testplan['tests']['automated']:
                repositories.add(test['repository'])
    if tp_version == "Linaro Test Plan v1":
        for req in testplan['requirements']:
            if 'tests' in req.keys() and req['tests'] is not None:
                if 'manual' in req['tests'].keys() and req['tests']['manual'] is not None:
                    for test in req['tests']['manual']:
                        repositories.add(test['repository'])
                if 'automated' in req['tests'].keys() and req['tests']['automated'] is not None:
                    for test in req['tests']['automated']:
                        repositories.add(test['repository'])
    return repositories


def clone_repository(repository_url, base_path, ignore=False):
    path_suffix = repository_url.rsplit("/", 1)[1]
    if path_suffix.endswith(".git"):
        path_suffix = path_suffix[:-4]

    path = os.path.abspath(os.path.join(base_path, path_suffix))
    if os.path.exists(path) and ignore:
        return(repository_url, path)
    # git clone repository_url
    subprocess.call(['git', 'clone', repository_url, path])
    # return tuple (repository_url, system_path)
    return (repository_url, path)


def test_exists(test, repositories, args):
    test_file_path = os.path.join(
        repositories[test['repository']],
        test['path']
    )
    current_dir = os.getcwd()
    print current_dir
    os.chdir(repositories[test['repository']])
    if 'revision' in test.keys():
        subprocess.call(['git', 'checkout', test['revision']])
    else:
        # if no revision is specified, use current HEAD
        output = subprocess.check_output(['git', 'rev-parse', 'HEAD'])
        test['revision'] = output

    if not os.path.exists(test_file_path) or not os.path.isfile(test_file_path):
        test['missing'] = True
        os.chdir(current_dir)
        return not test['missing']
    test['missing'] = False
    # open the file and render the test
    subprocess.call(['git', 'checkout', 'master'])
    print current_dir
    os.chdir(current_dir)
    print os.getcwd()
    test_file = open(test_file_path, "r")
    test_yaml = yaml.load(test_file.read())
    params_string = ""
    if 'parameters' in test.keys():
        params_string = "_".join(["{0}-{1}".format(param_name, param_value).replace("/", "").replace(" ", "") for param_name, param_value in test['parameters'].iteritems()])
        test_yaml['params'].update(test['parameters'])
        if args.single_output:
            # update parameters in test
            if 'params' in test_yaml.keys():
                for param_name, param_value in test_yaml['params'].iteritems():
                    if param_name not in test['parameters'].keys():
                        test['parameters'].update({param_name: param_value})
    print params_string
    test_name = "{0}_{1}.html".format(test_yaml['metadata']['name'], params_string)
    if not args.single_output:
        test['filename'] = test_name
    test_path = os.path.join(os.path.abspath(args.output), test_name)
    if args.single_output:
        # update test plan object
        test.update(test_yaml['run'])
        # prepend in reversed order so 'name' is on top
        test.prepend("os", test_yaml['metadata']['os'])
        test.prepend("scope", test_yaml['metadata']['scope'])
        test.prepend("description", test_yaml['metadata']['description'])
        test.prepend("name", test_yaml['metadata']['name'])
    else:
        render(test_yaml, template="test.html", name=test_path)
    return not test['missing']


def add_csv_row(requirement, test, args, manual=False):
    fieldnames = [
        "req_name",
        "req_owner",
        "req_category",
        "path",
        "repository",
        "revision",
        "parameters",
        "mandatory",
        "kind",
    ]
    csv_file_path = os.path.join(os.path.abspath(args.output), args.csv_name)
    has_header = False
    if os.path.isfile(csv_file_path):
        has_header = True
    with open(csv_file_path, "ab+") as csv_file:
        csvdict = DictWriter(csv_file, fieldnames=fieldnames)
        if not has_header:
            csvdict.writeheader()
        csvdict.writerow(
            {
                "req_name": requirement.get('name'),
                "req_owner": requirement.get('owner'),
                "req_category": requirement.get('category'),
                "path": test.get('path'),
                "repository": test.get('repository'),
                "revision": test.get('revision'),
                "parameters": test.get('parameters'),
                "mandatory": test.get('mandatory'),
                "kind": "manual" if manual else "automated",
            }
        )


def check_coverage(requirement, repositories, args):
    requirement['covered'] = False
    if 'tests' not in requirement.keys() or requirement['tests'] is None:
        return
    if 'manual' in requirement['tests'].keys() and requirement['tests']['manual'] is not None:
        for test in requirement['tests']['manual']:
            if test_exists(test, repositories, args):
                requirement['covered'] = True
            if args.csv_name:
                add_csv_row(requirement, test, args, True)
    if 'automated' in requirement['tests'].keys() and requirement['tests']['automated'] is not None:
        for test in requirement['tests']['automated']:
            if test_exists(test, repositories, args):
                requirement['covered'] = True
            if args.csv_name:
                add_csv_row(requirement, test, args)


def dict_representer(dumper, data):
    return dumper.represent_dict(data.iteritems())


def dict_constructor(loader, node):
    return PrependOrderedDict(loader.construct_pairs(node))


def main():
    parser = ArgumentParser()
    parser.add_argument("-f",
                        "--file",
                        dest="testplan_list",
                        required=True,
                        nargs="+",
                        help="Test plan file to be used")
    parser.add_argument("-r",
                        "--repositories",
                        dest="repository_path",
                        default="repositories",
                        help="Test plan file to be used")
    parser.add_argument("-o",
                        "--output",
                        dest="output",
                        default="output",
                        help="Destination directory for generated files")
    parser.add_argument("-i",
                        "--ignore-clone",
                        dest="ignore_clone",
                        action="store_true",
                        default=False,
                        help="Ignore cloning repositories and use previously cloned")
    parser.add_argument("-s",
                        "--single-file-output",
                        dest="single_output",
                        action="store_true",
                        default=False,
                        help="""Render test plan into single HTML file. This option ignores
                        any metadata that is available in test cases""")
    parser.add_argument("-c",
                        "--csv",
                        dest="csv_name",
                        required=False,
                        help="Name of CSV to store overall list of requirements and test. If name is absent, the file will not be generated")

    _mapping_tag = yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG
    yaml.add_representer(PrependOrderedDict, dict_representer)
    yaml.add_constructor(_mapping_tag, dict_constructor)

    args = parser.parse_args()
    if not os.path.exists(os.path.abspath(args.output)):
        os.makedirs(os.path.abspath(args.output), 0755)
    for testplan in args.testplan_list:
        if os.path.exists(testplan) and os.path.isfile(testplan):
            testplan_file = open(testplan, "r")
            tp_obj = yaml.load(testplan_file.read())
            repo_list = repository_list(tp_obj)
            repositories = {}
            for repo in repo_list:
                repo_url, repo_path = clone_repository(repo, args.repository_path, args.ignore_clone)
                repositories.update({repo_url: repo_path})
            # ToDo: check test plan structure

            tp_version = tp_obj['metadata']['format']
            if tp_version == "Linaro Test Plan v1":
                for requirement in tp_obj['requirements']:
                    check_coverage(requirement, repositories, args)
            if tp_version == "Linaro Test Plan v2":
                if 'manual' in tp_obj['tests'].keys() and tp_obj['tests']['manual'] is not None:
                    for test in tp_obj['tests']['manual']:
                        test_exists(test, repositories, args)
                if 'automated' in tp_obj['tests'].keys() and tp_obj['tests']['automated'] is not None:
                    for test in tp_obj['tests']['automated']:
                        test_exists(test, repositories, args)
            tp_name = tp_obj['metadata']['name'] + ".html"
            tp_file_name = os.path.join(os.path.abspath(args.output), tp_name)
            if tp_version == "Linaro Test Plan v1":
                render(tp_obj, name=tp_file_name)
            if tp_version == "Linaro Test Plan v2":
                render(tp_obj, name=tp_file_name, template="testplan_v2.html")
            testplan_file.close()
# go through requiremets and for each test:
#  - if file exists render test as separate html file
#  - if file is missing, indicate missing test (red)
# render test plan with links to test files
# add option to render as single file (for pdf generation)

if __name__ == "__main__":
    main()
