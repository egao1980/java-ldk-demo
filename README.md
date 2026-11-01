# java-ldk-demo

Reverse a string with [Apache Commons Lang](https://commons.apache.org/proper/commons-lang/) `StringUtils` on SBCL, through [`java-backend-openldk`](https://github.com/egao1980/java-backend-openldk). No JVM. Deps come from GHCR (`egao1980/cl-systems`) only.

`JAVA_HOME` must be a JDK 25. OpenLDK's own Temurin fetch is Linux-only.

```sh
export JAVA_HOME=/path/to/jdk-25
ros +Q run -- --dynamic-space-size 2048 --disable-debugger --load scripts/run.lisp
```

`+Q` keeps Quicklisp out of the image. On this Mac, Homebrew `openssl` is OpenSSL 4 and the published `cl+ssl` still calls `ASN1_STRING_data`; `scripts/run.lisp` points `cl+ssl` at `openssl@3` before the client loads.

```lisp
(java-ldk-demo:reverse-string "OpenLDK")  ; => "KDLnepO"
```

Jar: `org.apache.commons:commons-lang3:3.17.0`. Commons Codec `DigestUtils` is the wrong demo here: that path calls `java.security.MessageDigest`, and OpenLDK does not implement it.

The runtime is SBCL outside Windows (`sb-posix:mmap` in OpenLDK `src/jrt.lisp`). On Windows the test skips.
