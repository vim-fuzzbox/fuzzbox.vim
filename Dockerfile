# Use old, but maintained, Ubuntu LTS release
# Still widely used, e.g. Amazon Workspaces
FROM ubuntu:jammy

# Don't change this, used by docker-run to tidy old images
LABEL name="fuzzbox"

# Packages required to use git and install vim from source
RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
    make clang libncurses-dev git bash-completion less man-db ca-certificates

# Install Vim 9.0.0270 as included in old, but maintained, MacOS 13
RUN git clone --depth 1 --branch v9.0.0270 https://github.com/vim/vim.git
RUN cd vim/src && make && make install

# Minimalist vim config, makes things just about usable
RUN git clone https://github.com/tpope/vim-sensible.git /root/.vim/pack/plugins/start/sensible

# Add devicons for testing, requires compatible nerd font
RUN git clone https://github.com/ryanoasis/vim-devicons.git /root/.vim/pack/plugins/start/devicons

# Install lightline so statusline looks a bit prettier
RUN git clone https://github.com/itchyny/lightline.vim.git /root/.vim/pack/plugins/start/lightline

# Use a modern colorscheme included with Vim
RUN echo colorscheme habamax >> /root/.vimrc

# Allow hidden buffers with unsaved changes (for testing FuzzyBuffers)
RUN echo set hidden >> /root/.vimrc

# docker-run script mounts gitconfig, override editor and pager
ENV GIT_EDITOR=vim
ENV GIT_PAGER=less

# Fuzzbox needs UTF-8, but Ubuntu doesn't set LANG, so Vim defaults to Latin1
ENV LANG C.UTF-8

# Start in fuzzy dir, mounted by docker-run script
WORKDIR /root/.vim/pack/plugins/start/fuzzbox

CMD ["bash", "-l"]
