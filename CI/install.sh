brew install swiftlint
brew install libressl

swift --version
swift package tools-version --set-current
swift --version
swift package resolve
swift package clean

rm -rf /usr/local/var/postgres
initdb /usr/local/var/postgres -E utf8
pg_ctl -D /usr/local/var/postgres start && sleep 3 || true
sudo -u travis createuser -s -p 5432 postgres
psql -U postgres -c 'create database test;'
