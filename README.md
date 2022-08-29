# SimpleMCISoundPlayer
Simple sound player that use the MCI.<br />
I needed something that was able to play/stop and play in loop some mp3 so i made this.<br />
For the usage i suggest to read the code of the demo at<br />
https://github.com/TikoTako/SimpleMCISoundPlayerDemo<br />
<br />
<b>TODO finish readme</b>
<br />
````
        constructor Create(AOWner: TComponent); override;
        destructor Destroy(); override;
        function Open(FileName: string): bool;
        function Close(FileName: string): bool;
        function Play(FileName: string; Loop: bool = false): bool;
        function Rewind { Seek } (FileName: string): bool;
        function Stop(FileName: string): bool;
        procedure StopAll();
        function SetVolume(FileName: string; _volume: integer): bool;
        function GetVolume(FileName: string): integer;
        function CheckIfFileIsOpen(FileName: string): bool;
        function GetErrorStringFromCode(ErrorCode: Cardinal): string;
        property GetLastError: Cardinal read fLastError;
````

create > open > play/stop/rewind > close > free


fLastError is set by each SendCommand so you should check the GetLastError after any function call



get/set volume are per file not global
