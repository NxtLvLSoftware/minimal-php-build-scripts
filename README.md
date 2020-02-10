Minimal PHP Build Scripts
===================
__Scripts used to compile minimal php builds on multiple platforms for extension CI/testing.__

## compile.sh

Bash script used to compile PHP on MacOS and Linux platforms. Make sure you have
``make autoconf automake libtool m4 wget bison g++ cmake``.

### Additional notes
#### Mac OSX (native compile)
- Most dependencies can be installed using Homebrew
- You will additionally need `glibtool` (GNU libtool, xcode libtool won't work)
- You also MUST specify target as `mac` or `mac64` if building for Mac, on Mac.

| Script flags     | Description                                                        |
| --------------- | ------------------------------------------------------------------ |
| -t              | Set target                                                         |
| -j              | Set make threads to #                                              |
| -s              | Will compile everything statically                                 |
| -z              | Will enable php ZTS for the build                                  |

### Example:

| Target          | Arguments                                                          |
| --------------- | ------------------------------------------------------------------ |
| linux64         | ``-t linux64 -j $(nproc) -sz``                                     |
| mac64           | ``-t mac64 -j $(sysctl -n hw.physicalcpu) -sz``                    |

### Common pitfalls
- Avoid using the script in directory trees containing spaces or any other special characters. Some libraries don't like
trying to be built in directory trees containing spaces, e.g. `/home/user/my folder/pocketmine-mp/` might experience
problems.

## more platforms coming soon
Windows support is planned.

## Support and feature requests
Please submit anything that requires our attention to our [issue tracker](https://github.com/NxtLvLSoftware/minimal-php-build-scripts/issues)
on Github. We will attempt to respond to sensible requests in a reasonable time frame.