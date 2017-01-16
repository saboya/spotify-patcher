# spotify-patcher
An utility to patch the Spotify linux binary to remove libraries that link to outdated symbols.

## Usage

```
./spotify_patcher.sh /path/to/spotify/binary
```

## What is this for?

The Spotify binary is built against libraries with specific symbols that are not the most recent version in some Linux distributions out there, such as OPENSSL_1.0.0. Because of that, running Spotify gives me this error on Gentoo for example:
```
spotify: /usr/lib64/libssl.so.1.0.0: version `OPENSSL_1.0.0' not found (required by spotify) 
spotify: /usr/lib64/libcrypto.so.1.0.0: version `OPENSSL_1.0.0' not found (required by spotify) 
spotify: /usr/lib64/libcurl.so.4: version `CURL_OPENSSL_3' not found (required by spotify)
```
This problem is not new and has been acknowledged by the company:

* https://community.spotify.com/t5/Desktop-Linux-Windows-Web-Player/The-return-of-the-libssl-trouble-on-Linux/td-p/1294802
* https://community.spotify.com/t5/Desktop-Linux-Windows-Web-Player/Install-with-libssl1-0-2/m-p/1463199

## What does it do?

It searches for problematic libraries and removes them from the required libraries table. The problematic libraries are:

* libssl.so
* libcrypto.so
* libcurl.so.4

## Isn't that dangerous?

I don't think so, but use it at your own risk.

## Testing

This has been tested on 64-bit binaries, as in I used Spotify extensively and had no issues. I wrote the patcher to work with 32-bit binaries as well, but the only test I did with a 32-bit binary was applying the patch and checking the binary with readelf.

This is known to work with Spotify 1.0.45 and 1.0.47 64-bit.

This script is not POSIX-compliant. I wrote it with Bash in mind, may or may not work with other shells.

## Known issues

This script probably won't work if one of the problematic libraries is the first or last in the .gnu.version_r table. I intend to address this soon™.

## Useful resources

* https://en.wikipedia.org/wiki/Executable_and_Linkable_Format#Section_header
* https://refspecs.linuxfoundation.org/LSB_5.0.0/LSB-Core-generic/LSB-Core-generic/symversion.html
