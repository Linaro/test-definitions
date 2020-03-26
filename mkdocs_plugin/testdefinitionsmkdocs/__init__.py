import errno
import mdutils
import os
import yaml

from mkdocs.plugins import BasePlugin
from mkdocs.structure.files import File
from mdutils.fileutils.fileutils import MarkDownFile


class LinaroTestDefinitionsMkDocsPlugin(BasePlugin):
    def generate_yaml_markdown(self, filename, config):
        # remove leading ./
        new_filename = filename.split("/", 1)[1]
        # remove .yaml
        new_filename = new_filename.rsplit(".", 1)[0]
        tmp_filename = os.path.join(config['docs_dir'], new_filename)
        filecontent = None
        try:
            with open(filename, "r") as f:
                filecontent = f.read()
        except FileNotFoundError:
            return None
        try:
            content = yaml.load(filecontent, Loader=yaml.Loader)
            if "metadata" in content.keys():
                metadata = content["metadata"]
                mdFile = mdutils.MdUtils(file_name=tmp_filename, title=metadata['name'])
                tags_section = "---\n"
                tags_section += "title: %s\n" % metadata['name']
                tags_section += "tags:\n"
                scope_list = metadata.get("scope", None)
                if scope_list is not None:
                    for item in scope_list:
                        tags_section += " - %s\n" % item
                tags_section += "---\n"
                mdFile.new_header(level=1, title="Test name: %s" % metadata['name'])
                mdFile.new_header(level=1, title="Description")
                mdFile.new_paragraph(metadata['description'])
                mdFile.new_header(level=1, title="Maintainer")
                maintainer_list = metadata.get("maintainer", None)
                if maintainer_list is not None:
                    for item in maintainer_list:
                        mdFile.new_line(" * %s" % item)
                mdFile.new_header(level=1, title="Scope")
                if scope_list is not None:
                    for item in scope_list:
                        mdFile.new_line(" * %s" % item)
                try:
                    os.makedirs(os.path.dirname(tmp_filename))
                except OSError as exc:  # Guard against race condition
                    if exc.errno != errno.EEXIST:
                        raise
                md_file = MarkDownFile(mdFile.file_name)
                md_file.rewrite_all_file(data=tags_section + mdFile.title + mdFile.table_of_contents + mdFile.file_data_text)
                return new_filename + ".md"
        except yaml.YAMLError:
            return None
        except KeyError:
            return None

    def on_files(self, files, config):
        for root, dirs, filenames in os.walk("."):
            for filename in filenames:
                if filename.endswith(".yaml"):
                    new_filename = os.path.join(root, filename)
                    markdown_filename = self.generate_yaml_markdown(new_filename, config)
                    if markdown_filename is not None:
                        f = File(markdown_filename, config['docs_dir'], config['site_dir'], False)
                        files.append(f)
        return files
