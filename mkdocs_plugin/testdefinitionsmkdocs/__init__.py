import errno
import mdutils
import os
import yaml

from mkdocs.plugins import BasePlugin
from mkdocs.structure.files import File
from mkdocs.config.config_options import Type
from mdutils.fileutils.fileutils import MarkDownFile


class LinaroTestDefinitionsMkDocsPlugin(BasePlugin):
    config_scheme = (
        ("table_file", Type(str, default="tests_table")),
        ("table_dirs", Type(list, default=["automated", "manual"])),
    )

    def __init__(self):
        self.table_dirs = ["automated", "manual"]
        self.table_filename = "tests_table"
        self.test_tables = {}

    def on_config(self, config, **kwargs):
        self.table_filename = self.config.get("table_file", self.table_filename)
        self.table_dirs = self.config.get("table_dirs", self.table_dirs)
        for name in self.table_dirs:
            self.test_tables[name] = []

    def __add_list_with_header(self, mdFile, header_string, item_list):
        mdFile.new_header(level=2, title=header_string)
        if item_list is not None:
            for item in item_list:
                mdFile.new_line(" * %s" % item)

    def generate_yaml_markdown(self, filename, config):
        # remove leading ./
        new_filename = filename.split("/", 1)[1]
        # remove .yaml
        new_filename = new_filename.rsplit(".", 1)[0]
        tmp_filename = os.path.join(config["docs_dir"], new_filename)
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
                mdFile = mdutils.MdUtils(file_name=tmp_filename)
                tags_section = "---\n"
                tags_section += "title: %s\n" % metadata["name"]
                scope_list = metadata.get("scope", [])
                os_list = metadata.get("os", [])
                device_list = metadata.get("devices", [])
                if scope_list:
                    tags_section += "tags:\n"
                    for item in scope_list:
                        tags_section += " - %s\n" % item
                tags_section += "---\n"
                mdFile.new_header(level=1, title=new_filename)
                mdFile.new_header(level=2, title="Description")
                mdFile.write(metadata["description"])
                mdFile.new_header(level=2, title="Maintainer")
                maintainer_list = metadata.get("maintainer", None)
                if maintainer_list is not None:
                    for item in maintainer_list:
                        mdFile.new_line(" * %s" % item)
                self.__add_list_with_header(mdFile, "OS", os_list)
                self.__add_list_with_header(mdFile, "Scope", scope_list)
                self.__add_list_with_header(mdFile, "Devices", device_list)
                mdFile.new_header(level=2, title="Steps to reproduce")
                steps_list = content["run"]["steps"]
                for line in steps_list:
                    bullet_string = " * "
                    if str(line).startswith("#"):
                        bullet_string = " * \\"
                    mdFile.new_line(bullet_string + str(line))
                try:
                    os.makedirs(os.path.dirname(tmp_filename))
                except OSError as exc:  # Guard against race condition
                    if exc.errno != errno.EEXIST:
                        raise
                md_file = MarkDownFile(mdFile.file_name)
                md_file.rewrite_all_file(
                    data=tags_section
                    + mdFile.title
                    + mdFile.table_of_contents
                    + mdFile.file_data_text
                )
                # add row to tests_table
                table_key = None
                for table_name in self.table_dirs:
                    if new_filename.startswith(table_name):
                        table_key = table_name
                if table_key is not None:
                    self.test_tables[table_key].append(
                        {
                            "name": "[%s](%s.md)" % (metadata["name"], new_filename),
                            "description": metadata["description"],
                            "scope": ", ".join(
                                [
                                    "[%s](tags.md#%s)"
                                    % (x, x.lower().replace(" ", "-").replace("/", ""))
                                    for x in scope_list
                                ]
                            ),
                        }
                    )
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
                    markdown_filename = self.generate_yaml_markdown(
                        new_filename, config
                    )
                    if markdown_filename is not None:
                        f = File(
                            markdown_filename,
                            config["docs_dir"],
                            config["site_dir"],
                            False,
                        )
                        files.append(f)
        mdFile = mdutils.MdUtils(
            file_name=config["docs_dir"] + "/" + self.table_filename
        )
        mdFile.new_header(level=1, title="Tests index")
        for table_name, test_table in self.test_tables.items():
            mdFile.new_header(level=2, title='<span class="tag">%s</span>' % table_name)
            mdFile.new_line("| Name | Description | Scope |")
            mdFile.new_line("| --- | --- | --- |")
            for row in sorted(test_table, key=lambda item: item["name"]):
                mdFile.new_line(
                    "| %s | %s | %s |"
                    % (row["name"], row["description"].replace("\n", ""), row["scope"])
                )
            mdFile.new_line("")
        mdFile.create_md_file()
        newfile = File(
            path=str(self.table_filename) + ".md",
            src_dir=config["docs_dir"],
            dest_dir=config["site_dir"],
            use_directory_urls=False,
        )
        files.append(newfile)
        return sorted(files, key=lambda x: x.src_path, reverse=False)
