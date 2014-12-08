# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

umask 002
PS1='[\h]$ '

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

_pkgbits="$HOME/philo/pkg"
_localbits="$HOME/local"
PATH="${_localbits}/sbin:${_localbits}/bin:${_pkgbits}/sbin:${_pkgbits}/bin:$PATH"

keychain --quiet ~/.ssh/id_rsa
. $HOME/.keychain/`hostname`-sh 2>/dev/null

make()
{
	local _MK
	_MK=mk/bsd.pkg.mk
	if [ -f ../../$_MK -o -f ../$_MK -o -f $_MK ]; then
		bmake "$@"
	else
		/usr/bin/make "$@"
	fi
}
