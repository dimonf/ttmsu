This is convenience function which automates some operations pertained to `tmsu tag` command:
  - gets full path to the file from external function. In my case I fetch currently played file from `mpv` via socket
  - gets timestamp from the file or external function and stores it as tag value date=YYYYMMDD:HHMM
  - gets source reference from user input or external function and stores it as tag value source=[http://example.com|"mobile phone"|"web camera"|"Whatsapp"]
  - moves/copies file into predefined storage. I use
  

The function is registered for autocompletion
>compdef ttmsu=tmsu

To get autocompletion work, call to the function shall be accompanied by 'tag', as 1st positional argument.
