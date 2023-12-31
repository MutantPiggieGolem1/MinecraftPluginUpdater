#!/bin/bash
# Waterfall Version
FILE="./plugins.json"
if ! [ -f $FILE ]; then
	echo '[{"source": "WATERFALL", "repo": ""}]' > ./plugins.json
	echo "Please fill plugins.json."
	exit 1
fi
data=$(<$FILE)
for (( i=0 ; i<$(jq length $FILE) ; i++ )); do
	dat=$(jq ".[$i]" <<< "$data")
	title=$(jq -r '.repo' <<< "$dat")
	case $(jq -r '.source // empty' <<< "$dat") in
	WATERFALL)
		title="waterfall"
		mcver=$(curl -s https://api.papermc.io/v2/projects/waterfall/ -H "Accept: application/json" | jq -r '.version_groups | last')
		build=$(curl -s "https://api.papermc.io/v2/projects/waterfall/versions/$mcver/builds" -H "Accept: application/json" | jq -r '.builds[-1].build')
		vers="$mcver-$build"
		url="https://api.papermc.io/v2/projects/waterfall/versions/$mcver/builds/$build/downloads/waterfall-$mcver-$build.jar"
	;;
	LUCKPERMS)
		title="LuckPerms-Bungee"
		buildurl=$(jq -r ".builds[0].url" <<< "$(curl -s https://ci.lucko.me/job/LuckPerms/api/json)")
		info=$(jq -r '.artifacts | map(select(.fileName|startswith("LuckPerms-Bungee-"))) | .[]' <<< "$(curl -s "${buildurl}api/json")")
		temp=$(jq -r ".fileName" <<< "$info")
		# shellcheck disable=SC2206
		temp=(${temp//-/ })
		vers=${temp[-1]/.jar/}
		url="${buildurl}artifact/$(jq -r ".relativePath" <<< "$info")"
	;;
	SPIGOT)
		id=$(jq -r '.id // empty' <<< "$dat")
		if [ -z "$id" ]; then
			id=$(jq -r '.[0].id' <<< "$(curl -s -X GET "https://api.spiget.org/v2/search/resources/$title?field=name&size=1")")
			if [ -z "$id" ] || [ "$id" = "null" ]; then
				echo "Warning: No Spigot ID found for $title"
				continue
			fi
			data=$(jq ".[$i].id=$id" <<< "$data")
		fi
		vers=$(jq -r '.id' <<< "$(curl -s -X GET "https://api.spiget.org/v2/resources/$id/versions/latest")")
		url="https://api.spiget.org/v2/resources/$id/download" # this doesnt directly reference the version because when that happens the jars dont download
	;;
	MODRINTH)
		resp=$(curl -sg -X GET "https://api.modrinth.com/v2/project/$title/version?loaders=[%22bungeecord%22,%22waterfall%22]&version_type=release")
		resp=$(jq -r '.[0]' <<< "$resp")
		vers=$(jq -r '.version_number' <<< "$resp")
		url=$(jq -r '.files | map(select((.filename|endswith(".jar")) and .primary)) | .[].url' <<< "$resp")
	;;
	GITHUB | *)
		resp=$(curl -s -X GET "https://api.github.com/repos/$(jq -r '.owner' <<< "$dat")/$title/releases")
		resp=$(jq -r '.[0]' <<< "$resp")
		vers=$(jq -r '.tag_name' <<< "$resp")
		url=$(jq -r '.assets | map(select(.name|endswith(".jar"))) | .[].browser_download_url' <<< "$resp")
	;;
	esac
	if [ "$(jq -r 'has("ver")' <<< "$dat")" = "true" ] && [ "$vers" = "$(jq -r '.ver' <<< "$dat")" ]; then
		echo "Up To Date: [$title $vers]"
		continue
	fi
	if [ -z "$url" ]; then
		echo "Warning: No asset found for $title"
		continue
	fi
	echo "Updating: $title -> $vers"
	if [ "$title" == "waterfall" ]; then
		curl -L -o "$title.jar" "$url"
	else
		curl -L -o "plugins/$title.jar" "$url"
	fi
	data=$(jq ".[$i].ver=\"$vers\"" <<< "$data")
done
echo "$data" > $FILE
