/* Put in this file any --langdef --regex options */
/* Note that separate langdef options must be in separate strings separated by commas */
/* This file will be #include'd straight into the argument array */

"--langdef=css",
"--regex-css=/[ \t]*([^ \t\}]+)[ \t]*\{/\1/Selector/i",

