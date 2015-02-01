A hacky work in progress wrapper for http://dynalon.github.io/mdwiki/#!index.md with auth0.com authentication and git hooks for updates

You probably don't want to even think of using this yet.

## Configuration through ENV

|Variable|Description|
|--------|-----------|
|ROOT_FILE|The file to be read for requests to /, defaults to ```mdwiki.html```|
|WIKI_ROOT|Directory on disk where the wiki markdowns live, defaults to ```wiki``` in the dir where ```config.ru``` is|
|LOCAL_DEV|Set during development preview, disables authentication|
|SESSION_SECRET|Rack session secret, long random string, do not change once chosen|
|AUTH0_DOMAIN|Your auth0.com domain|
|AUTH0_CLIENT_ID|Your auth0.com client id|
|AUTH0_CLIENT_SECRET|Your auth0.com client secret|
|HOOKS|Set to 1 to enable the use of hook|
|HOOK_SIMPLE|Set to 0 to disable the simple hook that will try to git update the ```WIKI_ROOT```|
|HOOK_GITHUB|Set to 0 to disable the GitHub hook that will try to git update the ```WIKI_ROOT```|
|HOOK_BITBUCKET|Set to 0 to disable the Bit Bucket hook that will try to git update the ```WIKI_ROOT```|
