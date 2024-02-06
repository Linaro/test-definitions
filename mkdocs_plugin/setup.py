from setuptools import setup, find_packages


setup(
    name="mkdocs-test-definitions-plugin",
    version="1.5",
    description="An MkDocs plugin that converts LAVA test definitions to documentation",
    long_description="",
    keywords="mkdocs python markdown wiki",
    url="https://github.com/linaro/test-definitions",
    author="Milosz Wasilewski",
    author_email="milosz.wasilewski@linaro.org",
    license="GPL",
    python_requires=">=3.5",
    install_requires=["mkdocs>=1.1", "tags-macros-plugin"],
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Intended Audience :: Information Technology",
        "License :: OSI Approved :: GNU General Public License v2 or later (GPLv2+)",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: 3.5",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
    ],
    packages=find_packages(),
    entry_points={
        "mkdocs.plugins": [
            "linaro-test-definitions = testdefinitionsmkdocs:LinaroTestDefinitionsMkDocsPlugin"
        ]
    },
)
