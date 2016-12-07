import os
import subprocess
import yaml
from argparse import ArgumentParser
from csv import DictWriter
from jinja2 import Environment, FileSystemLoader


def render(obj, template="testplan.html", name=None):
    if name is None:
        name = template
    _env = Environment(loader=FileSystemLoader('templates'))
    _template = _env.get_template(template)
    _obj = _template.render(obj=obj)
    with open("{}".format(name), "wb") as _file:
        _file.write(_obj.encode('utf-8'))


# get list of repositories and cache them
def repository_list(testplan):
    repositories = set()
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
    print params_string
    test_name = "{0}_{1}.html".format(test_yaml['metadata']['name'], params_string)
    test['filename'] = test_name
    test_path = os.path.join(os.path.abspath(args.output), test_name)
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
    parser.add_argument("-c",
                        "--csv",
                        dest="csv_name",
                        required=False,
                        help="Name of CSV to store overall list of requirements and test. If name is absent, the file will not be generated")

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
            for requirement in tp_obj['requirements']:
                check_coverage(requirement, repositories, args)
            tp_name = tp_obj['metadata']['name'] + ".html"
            tp_file_name = os.path.join(os.path.abspath(args.output), tp_name)
            render(tp_obj, name=tp_file_name)
            testplan_file.close()
# go through requiremets and for each test:
#  - if file exists render test as separate html file
#  - if file is missing, indicate missing test (red)
# render test plan with links to test files
# add option to render as single file (for pdf generation)

if __name__ == "__main__":
    main()
