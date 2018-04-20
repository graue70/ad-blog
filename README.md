AD Blog
=======
This is the source repository of the [AD Blog](https://ad-blog.informatik.uni-freiburg.de)

The blog uses the [hugo](https://gohugo.io) site generator and our [custom
theme](https://ad-git.informatik.uni-freiburg.de/ad/ad-blog-theme).

Getting Started
---------------
Clone the repository **Note** that this project uses *git submodule*s and thus
needs to be cloned with

    git clone --recursive git@ad-git.informatik.uni-freiburg.de:ad/ad-blog.git

Alternatively if you already cloned without `--recursive` you can do an initial
checkout of the submodule with

    git submodule update --init --recursive

## Prerequisites
To preview and/or update the blog you currently need the hugo static site
generator. As this is a single binary
[installation](https://gohugo.io/getting-started/installing) is as simple as
copying the correct [binary](https://github.com/gohugoio/hugo/releases)
somewhere in your path. So as not to pollute your system paths we recommend to
create a `~/bin` directory and adding this to your `$PATH` variable in the
`~/.profile` or `~/.zshenv`.

## Creating a Post
To create a new post first run the following `hugo` command that creates
a skeleton post.

    hugo new post/my-awesome-title.md

It then tells you which file it created. This file can now be filled with all
your awesome content ✍️

The skeleton contains a YAML front matter metadata header like

    ---
    title: "My Awesome Title"
    date: 2018-04-12T12:43:04+02:00
    author: "Ada Lovelace"
    authorAvatar: "img/ada.jpg"
    tags: []
    categories: []
    image: "img/writing.jpg"
    draft: true
    ---

which should be customized to the post and author

After this you should add your summary and content

    Summary goes here
    <!--more-->
    Content goes here

### Adding Mathematical Formulæ
For adding math [MathJAX](https://www.mathjax.org) has been added and
preconfigured for the use with LaTeX. For an example refer to the 

### Adding Static Content
Static content can be added to the `static/` folder, it is automatically synced
to the correct destination on building

## Changing the Title, Description and Menu
These can be changed in the `config.[toml|yaml]` file. However in the future
the syntax (TOML) may change to match the post metadata (YAML)

## Changing the About Page
The about page is editable through the `content/about.md` file

Previewing
----------
To preview the site run the following `hugo` command which executes an embedded
webserver and change watcher

    hugo serve -D --bind "::" --baseURL $(hostname -f)

The `-D` option turns on rendering of draft posts i.e. those whith `draft:
true` in the front matter metadata section. The `--bind` and `--baseURL`
options are only needed if you are working on a remote system but would like to
view locally.

Building the Site
-----------------
The above preview only generates the site in-memory, to generate the static
HTML run the following command

    hugo

Again, adding `-D` also generates draft posts.

Deploying
---------
To deploy `rsync` the public folder to your web root

    ./deploy.sh
