web: $(npm bin)/browserify -t coffeeify --extension=".coffee" -p [ licensify --scanBrowser ] coffee/index.coffee > priv/bundle.js && erl -pa ebin deps/*/ebin -noshell -s message_wall start
