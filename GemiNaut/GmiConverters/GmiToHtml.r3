REBOL [

    title: "GMI to html converter"
    
]

;===================================================
;    GemiNaut, a friendly browser for Gemini space on Windows
;    (and for related plucked instruments).
;
;    Copyright (C) 2020, Luke Emmet 
;
;    Email: luke [dot] emmet [at] gmail [dot] com
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <https://www.gnu.org/licenses/>.
;===================================================

do load %utils.r3
do load %link-builder.r3


arg-block:  system/options/args

if (error? try [
    in-path:  to-rebol-file (to-string debase/base arg-block/1 64)
    out-path:  to-rebol-file (to-string debase/base arg-block/2 64)
    uri:   (to-string debase/base arg-block/3 64)
    theme:   (to-string debase/base arg-block/4 64)

        ;uri: "gemini://gemini.circumlunar.space/"

    ]) [
    
    folder: {C:\Users\lukee\Desktop\programming\projects\GemiNaut\GemiNaut\GmiConverters\TestContent\}

    in-path: to-rebol-file join folder {test1.gmi}
    out-path: to-rebol-file join folder {test1.htm}
    uri: "gemini://gemini.circumlunar.space/users/foo"
    theme: "Fabric"
    
     ;in-path: to-rebol-file {C:\Users\lukee\Desktop\geminaut\b8667ef276b02664b2c1980b5a5bcbe2.gmi}
     ;in-path: to-rebol-file {C:\Users\lukee\Desktop\geminaut\9fdfcb2ef4244d6821091d62e3a0e06a.gmi}
    ; in-path: to-rebol-file {C:/Users/lukee/AppData/Local/Temp/geminaut_hotlqkcz.e2l/118bce470e8723a2fdc1eec74dfcf991.txt}
    ; uri: "gemini://gemini.circumlunar.space:1965/users/supurb/"
     
]


uri-object:   decode-url uri

;---determine an theming identity hash for this site based on its url, to be used for identikon
;---and textured "fabric" style background
site-id: get-site-id uri-object
uri-md5: lowercase copy/part at (mold checksum/method (to-binary site-id) 'md5) 3 32

lines: read/lines in-path

out: copy []

in-block: false


newline-latch: off
previous-element-is-linkbullet: off

first-heading: copy ""
first-text-line: copy ""

foreach line lines [

    ;---simple hack for when user didnt add whitespace after link marker :-/
    replace line "=>" "=> "
    
    words: parse line none
    
    ;--start or end preformatted block. Use any label as the tooltip as
    ;-- a hint to the user -e.g. ```python
    if ((substring (trim copy line) 1 3) = "```") [
        
        pre-label: trim any [(substring line 4 (length? line))]
        if pre-label = "" [pre-label:  "preformatted text"]
       in-block: not in-block
        
        append out either in-block [
             rejoin [{<pre class=inline title="} pre-label {">} ]
        ] [
            "</pre>"
        ]
    ]
    
    insert-missing-preceding-line: func [] [
        
        if 1 < length? out [
            ;ensure certain items are preceded by a blank line
            ;apart from first line
            if (not newline-latch) and ("<div>&nbsp;</div>" <> last out) [
                append out  "<div>&nbsp;</div>" 
                newline-latch: on
            ]
        ]
    ]
    
    either not in-block [
        append/only out any [
            
            ;--handle headings, do most specific first so not to match later ones
            if (words/1 = "###") or ("###" = substring line 1 3) [
                 insert-missing-preceding-line
                 if first-heading = "" [first-heading: reform next words]
                 rejoin ["<h3>" (markup-escape reform next words) "</h3>"]
            ]


            if (words/1 = "##") or ("##" = substring line 1 2) [
                 insert-missing-preceding-line
                 if first-heading = "" [first-heading: reform next words]
                rejoin ["<h2>" (markup-escape reform next words) "</h2>"]
            ]

            if (words/1 = "#") or ("#" = substring line 1 1) [
                 insert-missing-preceding-line
                 if first-heading = "" [first-heading: reform next words]
                 rejoin ["<h1>" (markup-escape reform next words) "</h1>"]
            ]
        


            ;---handle *  bullets
            if (words/1 = "*") or ("*" = substring line 1 1) [
                if not previous-element-is-linkbullet [ insert-missing-preceding-line]
                 previous-element-is-linkbullet: on
                 rejoin ["<div class=bullet>&bull;&nbsp;" (markup-escape reform  next words) "</div>"]
            ]

            ;---handle links
            ;---assumes white space between "=>" and url (not always valid - can use substring or better parsing...
            if (words/1 = "=>") or ("=>" = substring line 1 2) [

                if not previous-element-is-linkbullet [ insert-missing-preceding-line]
                 previous-element-is-linkbullet: on

                link-part:  words/2
                
                either 2 < length? words [
                    display-part: (reform next next words)
                ] [
                    display-part: link-part
                ]
                
                link: build-link  uri-object link-part


                
                either (substring link 1 9) = "gemini://" [
                    class: "gemini"
                    link-gliph: "&rArr;"        ;---fat arrow like =>
                    link-class: "gemini-link"
                    
                    ;---try to guess from the url if this is a link to a binary file (not implemented at present)
                    ;---and warn the user in the tooltip. we cannot know for certain as we cannot do any kind of HEAD
                    ;---request in gemini. Here are the most common binary file types we might expect.
                    binary-extensions: [
                        "png" "gif" "jpg" "jpeg" 
                        "mp3" "wav" "ogg" "mp4" "midi" "flac"
                        "pdf" "doc" "docx" "odf" "epub" "mobi"
                        "tar" "gz" "zip"
                    ]
                    
                    url-split: parse/all link-part "."
                    link-extension: (lowercase last copy url-split)
                    display-extension: (lowercase last parse display-part ".")
                    
                    either find binary-extensions last url-split [
                        final-link-object: probe decode-url to-url link
                        
                        ;--decorate links to binary files with a unicode document glyph (&#128462;), 
                        ;--their expected file type and a tooltip to explain these are opened in system browser
                        display-html: rejoin [
                                {<span class=link-gliph>&#128462</span>&nbsp;<span }
                                    { title="Opens link to expected } (uppercase copy link-extension)
                                    { file in system web browser:}
                                    { } (last parse/all link   "/")
                                {">} 
                                (markup-escape display-part)
                                
                                ;show extension if not visible 
                                either (link-extension <> display-extension) [
                                    rejoin [" [" link-extension "]"]
                                ] [""]
                                                                
                                "</span>"]
                                
                            ;use an http/html proxy for these binary files which will open
                            ;in users standard browser. In future we might handle them directly.
                            link: rejoin [
                                "https://portal.mozz.us/gemini"
                                "/"
                                final-link-object/host
                                final-link-object/path
                                "?raw=1"
                            ]                        

                    ] [
                        display-html: markup-escape display-part
                    ]
                
                ] [
                    display-html: markup-escape display-part
                    class: "other"
                    link-gliph: "&#8669;"   ;---squiggle arrow for non gemini targets to aid recognition
                    link-class: "other-link"

                ]
                
               rejoin [
                    {<div class="} link-class {">}
                {<span class="link-gliph">} link-gliph {</span>} 
                    {&nbsp;<a } 
                        { href="} link {"}
                        { title="} link {"}
                        { class="} class {"}
                        {>}   (trim display-html) "</a></div>"
                ]
            ]
            
            if ((substring (trim copy line) 1 3) = "```") [""]

            ;--default - not a spaced item
            if true [                
                newline-latch: off
                
                
               either line = "" [
                        display-html: "<div>&nbsp;</div>"
                ] [
                    if previous-element-is-linkbullet [
                        insert-missing-preceding-line
                        previous-element-is-linkbullet: off
                    ]    
                    
                    if first-text-line = "" [first-text-line: join (substring line 1 100) "..."]

                    display-html:  rejoin ["<div>" markup-escape line "</div>"]
                ]
                
               
                :display-html
                
            ]
        ]
    ] [
            if ((substring (trim copy line) 1 3) <> "```") [
                append/only out markup-escape line
            ]
    ]

]

out-string: copy ""

foreach line out [
    append out-string join  line  newline
]

;---pad with some empty lines, if less than 30 otherwise looks strange on short content
for n 1 (30 - length? out) 1 [
    append out-string join "<div>&nbsp;</div>" newline
]

page-title: any [
    if first-heading <> "" [first-heading]
    if first-text-line <> "" [first-text-line]
    uri
]
    
;--save the content to a HTML file
;--theme html should be UTF-8 charset, which is the standard format.
theme-html: read/string to-file rejoin [theme ".htm"]
theme-css: read/string to-file rejoin [theme ".css"]


;populate the theme
replace/all theme-html "{{title}}" page-title
replace/all theme-html "{{theme-css}}" theme-css
replace/all theme-html "{{site-id}}" site-id
replace/all theme-html "{{site-id-md5}}" uri-md5
replace/all theme-html "{{site-id-md5-reversed}}" (reverse copy uri-md5)
replace/all theme-html "{{content}}" out-string

;save to final location
write out-path  theme-html