HEC - Html Export Compiler
==========================

This is essentially just a build script written in BASH-script. It compiles together the HTML export for an OSF document which resides at a ShowPad.

In order to do so, it requires a parameter $padname to be specified upon invocation. It invokes the specified pad's content, calls the parser of SimonWaldherr to parse the content, and prepends the HEADER data. Additionally it sorts the resulting file into the shownot.es "podcasts" directory and calls the browser to present the HTML file.

Dependencies
------------
Mainly GNU Linux. Most notably GNU bash, followed by GNU sed, and a lot of other commands which are shipped with a GNU Linux distro. I use the default **Ubuntu** to run the script. Trying to run the script on a Mac will probably fail, due to that grep and sed implementations differ.

License
-------
[GNU GPL version 3](http://www.gnu.org/licenses/gpl-3.0.html).

Setup
-----
HEC requires the *shownot.es* Repository which can be found under [shownotes/shownot.es](https://github.com/shownotes/shownot.es).

HEC comes with a config file `.hec_config`. You can set the path to where you put the shownot.es directory right after `out_dir=`. The line `include=` is only relevant, when you don't have all the HEC's files in one directory, or if you are running hec.sh from a different directory (such would also be the case, if you did put it into a sub folder). The other configuration options don't need to be altered for the script to run.

Example setup configuration:
----------------------------
I have my script at `/home/quimoniz/github/hec/hec.sh` the other HEC files are also in that directory, my shownot.es directory is at `/home/quimoniz/github/shownot.es` so I put in my configuration file:
```
include=./
out_dir=../shownot.es/
```
If I fancy to run hec.sh from within my shownot.es directory, I should instead use absolute paths:
```
include=/home/quimoniz/github/hec/
out_dir=/home/quimoniz/github/shownot.es/
```
Previous to this release HEC was distributed as *utilsh.tar.gz*, which was put in a sub folder of the shownot.es directory. It is still possible to set up HEC the old fashioned way. In order to do so, it is good practice to use absolute paths in the config file as mentioned above, like so `include=/home/quimoniz/github/shownot.es/.utilsh/`. **Note**, that in this case you will also have to add `.hec_config` to the `.gitignore` file in your shownot.es directory.

Usage
-----
Once set up, just invoke it with a pad name.
For example `bash hec.sh einschlafen-230`.

The script then requests the pad's contents, parses them, assumes a path name for the HTML output, writes to to it, and invokes the browser to present a preview.

**Note** that you may also specify an additional parameter `--preview` which adds a warning label to the output, stating that it is still in revision.

Reference
---------
The script won't do anything if the OSF has no HEADER

header fields:
<table>
    <tr>
        <th>name</th><th>necessary</th><th>description</th>
    </tr>
    <tr>
        <td>podcast</td><td>mandatory</td><td>name to use for looking up the podcast's "slug"</td>
    </tr>
    <tr>
        <td>episode</td><td>mandatory</td><td>only used to figure out the episode number</td>
    </tr>
    <tr>
        <td>podcaster</td><td>madatory</td><td>list of podcasters, will be passed to "form-userlist.sh"</td>
    </tr>
    <tr>
        <td>shownoter</td><td>mandatory</td><td>list of shownoters, will be passed to "form-userlist.sh"</td>
    </tr>
    <tr>
        <td>starttime</td><td>optional</td><td>for header field "Sendung vom"</td>
    </tr>
    <tr>
        <td>actual-starttime</td><td>optional</td><td>may override "starttime" if specified</td>
    </tr>
    <tr>
        <td>webseite</td><td>optional</td><td>the podcast's web page</td>
    </tr>
    <tr>
        <td>episodepage</td><td>optional</td><td>the specific episode's page</td>
    </tr>
    <tr>
        <td>episodetitle</td><td>optional</td><td>the specific title of this particular episode</td>
    </tr>
    <tr>
        <td>chatlog</td><td>optional</td><td>an optional link to a chat log, as used for NSFW</td>
    </tr>
</table>
