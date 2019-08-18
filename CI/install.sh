git clone https://github.com/Homebrew/linuxbrew.git ~/.linuxbrew

export PATH="$HOME/.linuxbrew/bin:$PATH"
export MANPATH="$HOME/.linuxbrew/share/man:$MANPATH"
export INFOPATH="$HOME/.linuxbrew/share/info:$INFOPATH"

brew install swiftlint
brew install libressl
brew install vapor/tap/vapor
brew install postgresql

sudo apt-get install clang
sudo apt-get install libcurl3 libpython2.7 libpython2.7-dev

wget https://swift.org/builds/swift-$SWIFT-VERSION-release/ubuntu1804/swift-$SWIFT-VERSION-RELEASE/swift-$SWIFT-VERSION-RELEASE-ubuntu18.04.tar.gz
tar xzf swift-$SWIFT_VERSION-RELEASE-ubuntu18.04.tar.gz
sudo mv swift-$SWIFT_VERSION-RELEASE-ubuntu18.04 /usr/share/swift
echo "export PATH=/usr/share/swift/usr/bin:$PATH" >> ~/.bashrc
source  ~/.bashrc

swift --version
swift package tools-version --set-current
swift package resolve
swift package clean

#rm -rf /usr/local/var/postgres
#initdb /usr/local/var/postgres -E utf8
#pg_ctl -D /usr/local/var/postgres start && sleep 3 || true
#sudo -u travis createuser -s -p 5432 postgres
#psql -U postgres -c 'create database test;'
