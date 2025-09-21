;;;    Copyright 2025 TarCV
;;;
;;; This file is part of an unofficial package collection for GNU Guix.
;;;
;;; This package collection is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; This package collection is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this package collection.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gradle)
  #:use-module (guix)
  #:use-module ((guix licenses)
                 #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cran)
  #:use-module (gnu packages docbook)
  #:use-module (gnu packages groovy)
  #:use-module (gnu packages java)
  #:use-module (gnu packages java-compression)
  #:use-module (gnu packages java-xml)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages maven)
  #:use-module (gnu packages maven-parent-pom)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages web)
  #:use-module (guix build utils)
  #:use-module (guix build-system ant)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system maven))

(define apache-ivy-2.0-beta2
  (package
    (inherit java-apache-ivy)
    (version "2.0.0-beta2")
    (source
      (origin
        (inherit (package-source java-apache-ivy))
        (uri (string-append "mirror://apache//ant/ivy/" version
               "/apache-ivy-" version "-src.tar.gz"))
        (sha256 (base32 "14nvi5hnjy4hdk42lyy959x3fp5khyyfvd9r3g8rbl97vpak3h0x"))
        (patches '())))))

; Avoid pack200 as it depends on old version of ASM library
(define java-commons-compress-no-pack200 ; TODO: patch package instead
  (package
    (inherit java-commons-compress)
    (propagated-inputs
      (list java-brotli
            java-osgi-core
            java-xz
            java-zstd
            apache-commons-parent-pom-52))
    (arguments
      (substitute-keyword-arguments (package-arguments java-commons-compress)
        ((#:phases phases)
          `(modify-phases ,phases
             (add-before 'build 'remove-pack200
               (lambda _
                 (delete-file-recursively "src/main/java/org/apache/commons/compress/compressors/pack200")
                 (delete-file-recursively "src/main/java/org/apache/commons/compress/harmony")
                 (delete-file "src/main/java/org/apache/commons/compress/compressors/CompressorStreamFactory.java")
                 (delete-file "src/main/java/org/apache/commons/compress/java/util/jar/Pack200.java")))))))))

(define java-minlog
  (package
    (name "java-minlog")
    (version "1.3.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/EsotericSoftware/minlog/archive/refs/tags/minlog-" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "0n7gx247ly9dgbdgwnhgh3r4ng7kamq95119nq7xcbifh09bhiy0"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (arguments
      `(#:jar-name "minlog.jar"
         #:source-dir "src"
         #:tests? #f ; no tests
         ))
    (home-page "https://github.com/EsotericSoftware/minlog")
    (synopsis "Minimal overhead Java logging")
    (description
      "MinLog is a tiny Java logging library which features:
- Zero overhead Logging statements below a given level can be automatically removed by javac at compile time. This means applications can have detailed trace and debug logging without having any impact on the finished product.
- Extremely lightweight The entire project consists of a single Java file with ~100 non-comment lines of code.
- Simple and efficient The API is concise and the code is very efficient at runtime.
")
    (license license:bsd-3)))

(define java-reflectasm
  (package
    (name "java-reflectasm")
    (version "1.11.9")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/EsotericSoftware/reflectasm/archive/refs/tags/reflectasm-" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "06ivmq8r5rrd3cvfwzavsp7r2ddavs3m7amph5j3n5y720gb70pv"))
        (patches '("patches/java-reflectasm-1.11.9-asm.patch"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-junit))
    (propagated-inputs (list java-asm-9)) ; TODO: should it be 9 here?
    (arguments
      `(#:jar-name "reflectasm.jar"
         #:source-dir "src"
         #:test-dir "test"
         #:phases ,#~(modify-phases %standard-phases
                         (add-before 'check 'fix-test-dir
                           (lambda _
                             (mkdir-p "test/java")
                             (rename-file "test/com" "test/java/com"))))))
    (home-page "https://github.com/EsotericSoftware/reflectasm")
    (synopsis "High performance Java reflection")
    (description
      "ReflectASM is a very small Java library that provides high performance reflection by using code generation. An access class is generated to set/get fields, call methods, or create a new instance. The access class uses bytecode rather than Java's reflection, so it is much faster. It can also access primitive fields via bytecode to avoid boxing.")
    (license license:bsd-3)))

(define java-kryo-2
  (package
    (name "java-kryo")
    (version "2.24.0")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/EsotericSoftware/kryo/archive/refs/tags/kryo-" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "0ffpkn89xzmgxbg8jzskpkikn2wqfvjhkydsagfhv79akn9j4sdb"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-junit))
    (propagated-inputs (list java-minlog java-objenesis java-reflectasm))
    (arguments
      `(#:jar-name "kryo.jar"
         #:source-dir "src"
         #:test-dir "test"
         #:phases ,#~(modify-phases %standard-phases
                         (add-before 'check 'fix-test-dir
                           (lambda _
                             (mkdir-p "test/java")
                             (rename-file "test/com" "test/java/com"))))))
    (home-page "https://github.com/EsotericSoftware/kryo")
    (synopsis "Java binary serialization and cloning: fast, efficient, automatic")
    (description
      "Kryo is a fast and efficient binary object graph serialization framework for Java. The goals of the project are high speed, low size, and an easy to use API. The project is useful any time objects need to be persisted, whether to a file, database, or over the network.")
    (license license:bsd-3)))

;(define java-jnr-constants
;  (package
;    (name "java-jnr-constants")
;    (version "0.7")
;    (source
;      (origin
;        (method url-fetch)
;        (uri (string-append "https://github.com/jnr/jnr-constants/archive/refs/tags/" version ".tar.gz"))
;        (file-name (string-append name "-" version ".tar.gz"))
;        (sha256 (base32 "1bj45843skcn6nwp6cwqyzfq6r4d8jmzd7h2pwfa86r5g81h9lnf"))
;        (modules '((guix build utils)))
;        (snippet '(begin ; TODO: Java files in this repo are pregenerated, should they be regenerated before build?
;                    (for-each delete-file
;                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
;                    #t))))
;    (build-system ant-build-system)
;    (arguments
;      `(#:make-flags
;         ,#~(list
;              (string-append "-Ddist.jar=" #$output "/share/java/jnr-constants.jar")
;              (string-append
;                 "-Dlibs.junit_4.classpath="
;                 #$java-junit "/lib/m2/junit/junit/" #$(package-version java-junit) "/junit-" #$(package-version java-junit) ".jar"
;                 ":" #$java-hamcrest-all "/share/java/hamcrest-all.jar"))
;         #:test-target "test"
;         #:phases (modify-phases %standard-phases
;           (delete 'install))))
;    (home-page "https://github.com/jnr/jnr-constants")
;    (synopsis "Java Native Runtime constants")
;    (description "This project contains Java enums for common POSIX constants. It is predominately used to make calls into jnr-posix far simpler.")
;    (license (list license:expat))))
;
;(define java-jnr-jffi-0.6
;  (package
;    (name "java-jnr-jffi")
;    (version "0.6.5")
;    (source
;      (origin
;        (method url-fetch)
;        (uri (string-append "https://github.com/jnr/jffi/archive/refs/tags/" version ".tar.gz"))
;        (file-name (string-append name "-" version ".tar.gz"))
;        (sha256 (base32 "1wm1h6zmv3jnv4mg7zk38ryxfphbwfgmkha1qawrpi0djpi6hnr4"))
;        (modules '((guix build utils)))
;        (patches '("patches/java-jnr-jffi-build.patch"))
;        (snippet '(begin
;                    (for-each delete-file
;                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
;                    #t))))
;    (build-system ant-build-system)
;    (native-inputs (list libffi pkg-config))
;    (arguments
;      `(#:test-target "test"
;        #:make-flags ,#~(list "-Duse.system.libffi=1"
;                           "-Dmkdist.disabled=true"
;                           (string-append "-Dcomplete.jar=" #$output "/share/java/jnr-jffi.jar")
;                           (string-append
;                             "-Dlibs.junit_4.classpath="
;                             #$java-junit "/lib/m2/junit/junit/" #$(package-version java-junit)
;                             "/junit-" #$(package-version java-junit) ".jar"
;                             ":" #$java-hamcrest-all "/share/java/hamcrest-all.jar"))
;        #:phases (modify-phases %standard-phases
;                    (add-before 'build 'setup-gnu-build-env
;                      (lambda _
;                        (substitute* '("jni/GNUmakefile" "libtest/GNUmakefile")
;                          (("(:.+)\\$\\(LIBFFI_LIBS\\)" all before) before)
;                          (("-mimpure-text") ""))
;                        (setenv "CC" "gcc")
;                        (setenv "MAKE" "make")))
;                    (delete 'install)))) ; complete.jar property already takes care of installing the jar
;    (home-page "https://github.com/jnr/jnr-jffi")
;    (synopsis "Java Foreign Function Interface")
;    (description "Java wrapper around libffi.")
;    (license (list license:lgpl3))))
;
;(define java-jnr-ffi
;  (package
;    (name "java-jnr-ffi")
;    (version "0.4.1")
;    (source
;      (origin
;        (method url-fetch)
;        (uri (string-append "https://github.com/jnr/jnr-ffi/archive/0462926916f8bf93e0a029248c3bfe9107bb99aa.tar.gz"))
;        (file-name (string-append name "-" version ".tar.gz"))
;        (sha256 (base32 "0lj0l8jyp36z2qx5d8gc31vck4m5gbsljrbminfnacqmgh3xarlk"))
;        (patches '("patches/java-jnr-ffi-asm.patch" "patches/java-jnr-ffi-generics.patch"))
;        (modules '((guix build utils)))
;        (snippet '(begin
;                    (for-each delete-file
;                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
;                    #t))))
;    (build-system ant-build-system)
;    (propagated-inputs (list java-asm java-jnr-jffi-0.6 java-native-access))
;    (arguments
;      `(#:test-target "test"
;         #:make-flags ,#~(list "-Duse.system.libffi=1"
;                               (string-append "-Ddist.jar=" #$output "/share/java/jnr-ffi.jar")
;                               (string-append "-Dfile.reference.asm-3.2.jar=" #$java-asm "/lib/m2/org/ow2/asm/asm/"
;                                 #$(package-version java-asm) "/asm-" #$(package-version java-asm) ".jar")
;                               (string-append "-Dreference.JNA_Library.jar=" #$java-native-access "/share/java/jna.jar")
;                               (string-append
;                                 "-Dlibs.junit_4.classpath="
;                                 #$java-junit "/lib/m2/junit/junit/" #$(package-version java-junit) "/junit-" #$(package-version java-junit) ".jar"
;                                 ":" #$java-hamcrest-all "/share/java/hamcrest-all.jar")
;                               (string-append "-Dfile.reference.jffi-complete.jar=" #$java-jnr-jffi-0.6 "/share/java/jnr-jffi.jar"))
;         #:phases (modify-phases %standard-phases
;                    (add-before 'build 'setup-gnu-build-env
;                      (lambda _
;                        (substitute* "libtest/GNUmakefile"
;                          (("-mimpure-text") ""))
;                        (setenv "CC" "gcc")
;                        (setenv "MAKE" "make")))
;                    (add-before 'build 'remove-nb-dependency
;                      (lambda _
;                        (substitute* "nbproject/build-impl.xml"
;                          ((",-do-jar-with-libraries[^,\"']+") ""))))
;                    (delete 'install)))) ; dist.jar property already takes care of installing the jar
;    (home-page "https://github.com/jnr/jnr-ffi")
;    (synopsis "Java Abstracted Foreign Function Layer")
;    (description "JNR-FFI is a Java library for loading native libraries without writing JNI code by hand, or using tools such as SWIG.")
;    (license (list license:expat))))
;
;(define java-jnr-posix
;  (package
;    (name "java-jnr-posix")
;    (version "1.0.8")
;    (source
;      (origin
;        (method url-fetch)
;        (uri (string-append "https://github.com/jnr/jnr-posix/archive/refs/tags/" version ".tar.gz"))
;        (file-name (string-append name "-" version ".tar.gz"))
;        (sha256 (base32 "1lrrislf8rzw9dz751721pki6wn92p36prb4hqd20rxgkjbqp2my"))
;        (modules '((guix build utils)))
;        (snippet '(begin
;                    (for-each delete-file
;                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
;                    #t))))
;    (build-system ant-build-system)
;    (propagated-inputs (list coreutils-minimal java-jnr-constants java-jnr-ffi))
;    (arguments
;      `(#:make-flags
;         ,#~(list
;           "-Dno.dependencies=true"
;           (string-append "-Ddist.jar=" #$output "/share/java/jnr-posix.jar")
;           (string-append "-Dreference.constantine.jar=" #$java-jnr-constants "/share/java/jnr-constants.jar")
;           (string-append "-Dreference.jaffl.jar=" #$java-jnr-ffi "/share/java/jnr-ffi.jar")
;           (string-append
;             "-Dlibs.junit_4.classpath="
;             #$java-junit "/lib/m2/junit/junit/" #$(package-version java-junit) "/junit-" #$(package-version java-junit) ".jar"
;             ":" #$java-hamcrest-all "/share/java/hamcrest-all.jar"))
;         #:test-target "test"
;         #:tests? #f ; TODO: fix libc related tests
;         #:phases ,#~(modify-phases %standard-phases
;                    (add-before 'build 'patch-bin-paths
;                      (lambda _
;                        (substitute* (find-files "src" ".*\\.java$")
;                          (("\"/usr/bin/") (string-append "\"" #$coreutils-minimal "/bin/")))))
;                    (delete 'install))))
;    (home-page "https://github.com/jnr/jnr-posix")
;    (synopsis "Java Posix layer")
;    (description "jnr-posix is a lightweight cross-platform POSIX emulation layer for Java, written in Java.")
;    (license (list license:cpl1.0 license:gpl2+ license:lgpl2.1+))))

(define java-fastutil-7
  (package
    (name "java-fastutil")
    (version "7.2.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/vigna/fastutil/archive/refs/tags/" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "06adanl4h1rhih54s3288m26jn603sj0phgjnrzgrak06zzz7pyl"))
        (patches '("patches/java-fastutil-7-junit.patch"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-junit))
    (arguments
      `(#:make-flags (list "-Dbuild.sysclasspath=last")
         #:test-target "junit"
         #:phases ,#~(modify-phases %standard-phases
                         (add-before 'build 'generate-sources
                           (lambda _
                             (setenv "CC" "gcc")
                             (invoke "make" "sources")))
                         (add-before 'check 'create-reports-dir
                           (lambda _
                             (mkdir-p "reports")))
                         (add-before 'install 'prepare-pom.xml
                           (lambda _
                             (substitute* "makefile"
                               (("; ant stage") ""))
                             (invoke "make" "stage")))
                         (replace 'install
                           (install-from-pom "pom.xml")))))
    (home-page "https://fastutil.di.unimi.it/")
    (synopsis "fastutil: Fast & compact type-specific collections for Java")
    (description "fastutil extends the Java™ Collections Framework by providing type-specific maps, sets, lists and queues with a small memory footprint and fast access and insertion; provides also big (64-bit) arrays, sets and lists, and fast, practical I/O classes for binary and text files.")
    (license (list license:asl2.0))))

(define java-jatl
  (package
    (name "java-jatl")
    (version "0.2.3")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/agentgt/jatl/archive/refs/tags/jatl-" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "0z3s4zpq97rwwn2gcfkhf28sib60d1sczg682fskyq1nfdxnlvgb"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-junit))
    (arguments
      `(#:jar-name "jatl.jar"
         #:phases ,#~(modify-phases %standard-phases
                         (add-after 'build 'copy-resources
                           (lambda _
                             (copy-recursively "src/etc" "build/classes")))
                         (replace 'install
                           (install-from-pom "pom.xml")))))
    (home-page "https://github.com/agentgt/jatl")
    (synopsis "JATL: Java Anti-Template Language")
    (description "JATL is an extremely lightweight efficient Java library that generates XHTML or XML by using an a elegant fluent styled micro DSL.")
    (license (list license:asl2.0))))

(define java-jhighlight
  (package
    (name "java-jhighlight")
    (version "1.1.0") ; TODO: compare with uwyn jhighlight
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/codelibs/jhighlight/archive/refs/tags/jhighlight-" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "1p0pavvkmrmaljk89aadq9a861dvssiv9iv4gzklgbwxmgf15r19"))
        (patches '("patches/java-jhighlight-1.1.0-new-servlet-api.patch"))))
    (build-system ant-build-system) ; because java-javaee-servletapi is not mavenized
    (native-inputs (list java-javaee-servletapi ; not propagated because servletapi is supposed to be provided
                         java-junit))
    (propagated-inputs (list java-commons-io))
    (arguments
      `(#:jar-name "jhighlight.jar"
        #:phases (modify-phases %standard-phases
                   (add-before 'build 'copy-resources
                     (lambda _
                       (copy-recursively "src/main/resources" "build/classes"))))))
    (home-page "https://github.com/codelibs/jhighlight")
    (synopsis "Embeddable pure Java syntax highlighting library")
    (description "JHighlight is an embeddable pure Java syntax highlighting library that supports Java, HTML, XHTML,
     XML and LZX languages and outputs to XHTML. It also supports RIFE templates tags and highlights them clearly so
      that you can easily identify the difference between your RIFE markup and the actual marked up source.")
    (license (list license:cddl1.0 license:lgpl2.1+))))

(define java-jul-to-slf4j
  (package
    (inherit java-slf4j-api)
    (name "java-jul-to-slf4j")
    (build-system ant-build-system)
    (propagated-inputs (list java-slf4j-api))
    (arguments
      `(#:jar-name "jul-to-slf4j.jar"
         #:source-dir "jul-to-slf4j/src/main"
         #:tests? #f ; tests require a newer version of java-log4j-1.2-api 2.17.2
         #:phases ,#~(modify-phases %standard-phases
                         (add-after 'build 'copy-resources
                           (lambda _
                             (copy-recursively "jul-to-slf4j/src/main/resources" "build/classes")))
                         (replace 'install
                           (install-from-pom "jul-to-slf4j/pom.xml")))))
    (home-page "https://www.slf4j.org/legacy.html")
    (synopsis "java.util.logging to Simple logging facade for Java bridge")))

(define java-native-platform-0.14
  (package
    (name "java-native-platform")
    (version "0.14")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/gradle/native-platform/archive/refs/tags/" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "1if8h1lz8rh6gv6rrych63j2a03cfcqshb5c2973xsfs7jfrvbrr"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (arguments
      `(#:jar-name "native-platform.jar"
         #:source-dir "src/main/java"
         #:tests? #f ; TODO
         #:phases ,#~(modify-phases %standard-phases
                         (add-after 'build 'generate-headers ; TODO: add native build phase
                           (lambda _
                             (invoke "javah"
                               "-o" "build/classes/nativeHeaders/native.h"
                               "-classpath" "build/classes"
                               "net.rubygrapefruit.platform.internal.jni.NativeLibraryFunctions"
                               "net.rubygrapefruit.platform.internal.jni.PosixFileFunctions"
                               "net.rubygrapefruit.platform.internal.jni.PosixFileSystemFunctions"
                               "net.rubygrapefruit.platform.internal.jni.PosixProcessFunctions"
                               "net.rubygrapefruit.platform.internal.jni.PosixTerminalFunctions"
                               "net.rubygrapefruit.platform.internal.jni.TerminfoFunctions"
                               "net.rubygrapefruit.platform.internal.jni.WindowsConsoleFunctions"
                               "net.rubygrapefruit.platform.internal.jni.WindowsHandleFunctions"
                               "net.rubygrapefruit.platform.internal.jni.WindowsRegistryFunctions"
                               "net.rubygrapefruit.platform.internal.jni.WindowsFileFunctions"
                               "net.rubygrapefruit.platform.internal.jni.FileEventFunctions"
                               "net.rubygrapefruit.platform.internal.jni.PosixTypeFunctions"
                               "net.rubygrapefruit.platform.internal.jni.MemoryFunctions"
                               "net.rubygrapefruit.platform.internal.jni.OsxMemoryFunctions"
                               ))))))
    (home-page "https://github.com/gradle/native-platform/")
    (synopsis "Native-platform: Java bindings for various native APIs")
    (description
      "A collection of cross-platform Java APIs for various native APIs. Supports OS X, Linux, Solaris and Windows. These APIs support Java 5 and later. Some of these APIs overlap with APIs available in later Java versions.")
    (license license:asl2.0)))

(define java-parboiled-core-1.1
  (package
    (name "java-parboiled-core")
    (version "1.1.8")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/sirthias/parboiled/archive/refs/tags/" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "0jq2xydc5mp3nnnvns4vhfnbbf0rw318bsmh5w6xa0c8ip8hj47z"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-testng))
    (arguments
      `(#:jar-name "parboiled-core.jar"
        #:make-flags (list "-Dant.build.javac.target" "1.5"
                           "-Dant.build.javac.source" "1.5")
        #:source-dir "parboiled-core/src/main/java"
        #:test-dir "parboiled-core/src/test"
        #:phases (modify-phases %standard-phases
                   (add-before 'check 'remove-scala-test-dependents
                     (lambda _
                       (delete-file "parboiled-core/src/test/java/CoreTest.java")))
                   (add-before 'check 'add-testng
                     (lambda _
                       (substitute* "build.xml"
                         (("<junit [^>]+>") "<taskdef resource=\"testngtasks\" classpathref=\"classpath\"/><testng haltonfailure=\"true\">")
                         (("<batchtest[^>]*><fileset[^>]*>.*</fileset></batchtest>")
                           "<classfileset dir=\"${test.classes.dir}\"><include name=\"**/*Test.class\" /><exclude name=\"**/Abstract*.class\" /></classfileset>")
                         (("</junit>") "</testng>"))
                       (substitute* "build.xml"
                         (("(<testng[^>]*>.*)<formatter[^>]*/>(.*</testng>)" _ prefix suffix)
                           (string-append prefix suffix)))))
                   (add-before 'install 'create-pom
                     (generate-pom.xml "pom.xml" "org.parboiled" "parboiled-core" ,version))
                   (replace 'install
                     (install-from-pom "pom.xml")))))
    (home-page "https://github.com/sirthias/parboiled/")
    (synopsis "Parboiled parsing library - Core module")
    (description "Elegant parsing in Java and Scala - lightweight, easy-to-use, powerful.")
    (license license:asl2.0)))

(define java-parboiled-1.1
  (package
    (inherit java-parboiled-core-1.1)
    (name "java-parboiled")
    (propagated-inputs (list java-asm java-parboiled-core-1.1))
    (arguments
      (substitute-keyword-arguments (package-arguments java-parboiled-core-1.1)
        ((#:jar-name _) "parboiled.jar")
        ((#:source-dir _) "parboiled-java/src/main/java")
        ((#:test-dir _) "parboiled-java/src/test")
        ((#:phases phases) `(modify-phases ,phases
                             (replace 'remove-scala-test-dependents
                               (lambda _
                                 (delete-file "parboiled-java/src/test/java/JavaTest.java")))
                             (add-before 'check 'enable-debug-for-compile-tests
                               (lambda _
                                 (substitute* "build.xml"
                                   (("(<target [^>]*name=\"compile-tests\">.*<javac [^>]*)(>.*</target><target [^>]*name=\"check\")" _ prefix suffix)
                                     (string-append prefix " debug=\"true\" " suffix)))))
                             (replace 'create-pom
                               (generate-pom.xml "pom.xml" "org.parboiled" "parboiled-java" ,(package-version java-parboiled-core-1.1)))))))
    (synopsis "Parboiled parsing library")))

(define java-pegdown
  (package
    (name "java-parboiled-core")
    (version "1.6.0")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/sirthias/pegdown/archive/refs/tags/" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "18y97gvsvpqc9i7wvrq5zs2ir8ycd7f1igz6qgibrhw14i118xmx"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (propagated-inputs (list java-parboiled-1.1))
    (arguments
      `(#:jar-name "pegdown.jar"
         #:make-flags (list "-Dant.build.javac.target" "1.6"
                            "-Dant.build.javac.source" "1.6")
         #:source-dir "src/main/java"
         #:tests? #f ; Tests depend on Scala
         #:phases (modify-phases %standard-phases
                    (add-before 'build 'enable-debug-symbols
                      (lambda _
                        (substitute* "build.xml"
                          (("(<javac [^>]*)(>)" _ prefix suffix) (string-append prefix " debug=\"true\" " suffix)))))
                    (add-before 'install 'create-pom
                      (generate-pom.xml "pom.xml" "org.pegdown" "pegdown" ,version))
                    (replace 'install
                      (install-from-pom "pom.xml")))))
    (home-page "https://github.com/sirthias/pegdown/")
    (synopsis "Java 1.6+ library providing a clean and lightweight markdown processor")
    (description "pegdown is a pure Java library for clean and lightweight Markdown processing based on a parboiled PEG parser.
pegdown is nearly 100% compatible with the original Markdown specification and fully passes the original Markdown test suite.")
    (license license:asl2.0)))

; TODO: (define js-jquery-1
;  (package
;    (name "js-jquery")
;    (version "1.12.4")
;    (source
;      (origin
;        (method url-fetch)
;        (uri (string-append "https://github.com/jquery/jquery/archive/refs/tags/" version ".tar.gz"))
;        (file-name (string-append "jquery-" version ".tar.gz"))
;        (sha256 (base32 "0y2i2akkq2p956594q0cxn68rk1vr417z7zmijifqp44skg8najj"))
;        (modules '((guix build utils)))
;        (snippet '(begin
;                    (delete-file-recursively "dist")
;                    (delete-file-recursively "external")))))
;    (build-system node-build-system)
;    (home-page "https://jquery.com/")
;    (synopsis "jQuery is a fast, small, and feature-rich JavaScript library")
;    (description "jQuery makes things like HTML document traversal and manipulation, event handling, animation, and Ajax
;     much simpler with an easy-to-use API that works across a multitude of browsers.")
;    (license license:expat)))

(define js-jquery-tiptip
  (package
    (name "js-jquery-tiptip")
    (version "1.3")
    (source
      (origin
        (method url-fetch)
        (uri "https://github.com/drewwilson/TipTip/archive/f4d2b6c9c9503857ce56bbb354c012f72722724a.tar.gz")
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "1hra6v2pmkcq30v7lvjlkh3d8slcjnm9d6bgb0z2pw6daif4cm6p"))
        (modules '((guix build utils)))
        (snippet '(delete-file "jquery.tipTip.minified.js"))))
    (native-inputs (list esbuild))
    (build-system gnu-build-system)
    (arguments
      `(#:phases
         (modify-phases %standard-phases
           (delete 'check)
           (delete 'configure)
           (delete 'install)
           (add-before 'build 'patch-header-to-be-preserved
             (lambda _
               (substitute* "jquery.tipTip.js"
                 (("/\\*") "/*!"))))
           (replace 'build
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let ((esbuild (string-append (assoc-ref inputs "esbuild")
                                "/bin/esbuild"))
                      (target (string-append (assoc-ref outputs "out")
                                "/share/javascript/" ,name)))
                 (invoke esbuild
                   "--minify"
                   "--target=chrome5,firefox3,ie8" ; Browser versions back in 2010
                   (string-append "--outfile=" target "/jquery.tipTip.minified.js")
                   "jquery.tipTip.js")))))))
    (home-page "https://github.com/drewwilson/TipTip")
    (synopsis "jQuery Plug-In for creating a custom tooltip to replace the default browser tooltip")
    (description "This plug-in is extremely lightweight and very smart in
that it detects the edges of the browser window and will make sure
the tooltip stays within the current window size. As a result the
tooltip will adjust itself to be displayed above, below, to the left 
or to the right depending on what is necessary to stay within the
browser window. It is completely customizable as well via CSS.")
    (license (list license:expat license:gpl1+))))

(define groovy-ant-patched
  (let ((original-groovy-ant (lookup-package-input groovy "groovy-ant")))
    (package
      (inherit original-groovy-ant)
      (source (origin
                (inherit (package-source original-groovy-ant))
                (patches
                  (append (origin-patches (package-source original-groovy-ant))
                    (list "patches/groovy-fix-groovyc-classpath.patch"))))))))

(define gradle-bootstrap
  (package
    (name "gradle")
    (version "4.5.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/gradle/gradle/archive/refs/tags/v" version ".tar.gz"))
        (file-name (string-append "gradle-" version ".tar.gz"))
        (sha256 (base32 "03yaq6kkdk5akjl5is0rmkdqhg1jfhp1mbv9jzpmjrs53z1hsxlw"))
        (patches '("patches/gradle-4.5.1-asm.patch"
                    "patches/gradle-4.5.1-groovy-2.4.patch" "patches/gradle-4.5.1-groovy-2.5-1.patch"
                    "patches/gradle-4.5.1-groovy-2.5-2.patch" "patches/gradle-4.5.1-groovy-2.5-3.patch"
                    "patches/gradle-4.5.1-groovy-2.5-4.patch" "patches/gradle-4.5.1-groovy-3.patch"
                    "patches/gradle-4.5.1-guava.patch" "patches/gradle-4.5.1-kryo.patch"
                    "patches/gradle-4.5.1-type-inference-fix.patch" "patches/gradle-4.5.1-type-fix.patch"

                    "patches/gradle-bootstrap-4.5.1-remove-dependencies.patch"
                    "patches/gradle-bootstrap-4.5.1-single-jar.patch"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (propagated-inputs
      (list groovy-ant-patched groovy
              java-asm-9 java-asm-commons-9
            java-apache-ivy java-bouncycastle java-commons-collections java-commons-compress-no-pack200
            java-commons-io java-commons-lang java-commons-logging-minimal
            java-fastutil-7 java-gson java-jansi-1 java-jatl java-jgit java-jsr305 java-jul-to-slf4j
            java-httpcomponents-httpclient java-httpcomponents-httpcore
            java-kryo-2 java-native-platform-0.14 java-slf4j-api java-testng maven-settings-builder))
    (arguments
      `(#:jdk ,openjdk9 ; same as groovy
         #:jar-name "gradle.jar"
         #:source-dir "merged-src/src/main"
         #:tests? #f ; too many dependencies are removed in this partial bootstrap build for tests to work
         #:phases (modify-phases %standard-phases
                    (add-after 'unpack 'prepare-merged-sources
                      (lambda _
                        (for-each
                          (lambda (d)
                            (copy-recursively d "merged-src"
                              #:copy-file (lambda (source target)
                                            (if (file-exists? target)
                                              (begin
                                                (write (string-append "Concatenating " source " into " target))
                                                (let ((targetPort (open-file target "a")))
                                                  (newline targetPort)
                                                  (call-with-input-file source
                                                    (lambda (sourcePort)
                                                      (let loop ((char (read-char sourcePort)))
                                                        (if (not (eof-object? char))
                                                          (begin
                                                            (display char targetPort)
                                                            (loop (read-char sourcePort)))))))
                                                  (close targetPort)))
                                              (copy-file source target)))))
                          (list
                            "subprojects/base-services"
                            "subprojects/base-services-groovy"
                            "subprojects/build-cache"
                            ;                        "subprojects/build-init"
                            "subprojects/build-option"
                            "subprojects/cli"
                            ;                        "subprojects/code-quality"
                            "subprojects/core"
                            "subprojects/composite-builds"
                            "subprojects/core-api"
                            "subprojects/core-impl"
                            "subprojects/dependency-management"
                            "subprojects/diagnostics"
                            ;                        "subprojects/docs"
                            ;                        "subprojects/ear"
                            ;                        "subprojects/installation-beacon"
                            "subprojects/javascript"
                            "subprojects/jvm-services"
                            "subprojects/language-groovy"
                            "subprojects/language-java"
                            "subprojects/language-jvm"
                            "subprojects/launcher"
                            "subprojects/logging"
                            ;                        "subprojects/maven"
                            "subprojects/messaging"
                            "subprojects/model-core"
                            "subprojects/model-groovy"
                            "subprojects/native"
                            "subprojects/persistent-cache"
                            "subprojects/platform-base"
                            "subprojects/platform-jvm"
                            "subprojects/plugin-development"
                            "subprojects/plugin-use"
                            "subprojects/plugins"
                            "subprojects/process-services"
                            "subprojects/reporting"
                            "subprojects/resources"
                            "subprojects/resources-http"
                            ;                        "subprojects/runtime-api-info"
                            ;                        "subprojects/test-kit"
                            "subprojects/testing-base"
                            "subprojects/testing-jvm"
                            "subprojects/tooling-api"
                            "subprojects/version-control"
                            "subprojects/workers"
                            ))))
                    (add-after 'prepare-merged-sources 'unshade-imports
                      (lambda _
                        (substitute* (find-files "merged-src" ".*\\.(java|groovy)$")
                          (("groovyjarjarasm") "org.objectweb") ; no dot at the end of the pattern as otherwise it would miss some package mentions
                          (("groovyjarjarantlr") "antlr")
                          (("org\\.gradle\\.mvn3.") ""))))
;                    (add-after 'prepare-merged-sources 'update-asm
;                      (lambda _
;                        (substitute* (find-files "merged-src" ".*\\.(java|groovy)$")
;                          (("ASM6") "ASM8"))))
                    (add-after 'prepare-merged-sources 'patch-jcip
                      (lambda _
                        (substitute* (find-files "merged-src" ".*\\.(java|groovy)$")
                          (("import net\\.jcip\\.annotations\\.((Not)?ThreadSafe;)" _ name)
                            (string-append "import javax.annotation.concurrent." name)))))
                    (add-after 'prepare-merged-sources 'patch-for-newer-guava
                      (lambda _
                        (substitute* (find-files "merged-src" ".*\\.(java|groovy)$")
                          (("import static com.google.common.collect.Iterators.emptyIterator;")
                            "import static java.util.Collections.emptyIterator;")
                          (("CharMatcher.JAVA_ISO_CONTROL") "CharMatcher.javaIsoControl()")
                          (("Iterators.emptyIterator\\(\\)") "java.util.Collections.emptyIterator()")
                          (("Objects.toStringHelper") "com.google.common.base.MoreObjects.toStringHelper"))))
                    (add-before 'build 'patch-build.xml
                      (lambda _
                        (substitute* "build.xml"
                          (("<javac ([^>]+)>" all args) (string-append
                                                          "<taskdef name=\"groovyc\" classname=\"org.codehaus.groovy.ant.Groovyc\" classpathref=\"classpath\"/>"
                                                          "<groovyc " args " fork=\"true\"><classpath refid=\"classpath\"/>"
                                                          "<javac debug=\"true\" " args ">"))
                          (("</javac>" all) (string-append all "</groovyc>")))))
                    (add-before 'build 'remove-dependencies
                      (lambda _
                        (delete-file-recursively
                          "merged-src/src/main/java/org/gradle/internal/resource/transport/http/ntlm")
                        ;                        (delete-file-recursively
                        ;                          "merged-src/src/main/java/org/gradle/api/publication/maven")
                        ;                        (delete-file-recursively
                        ;                          "merged-src/src/main/java/org/gradle/api/publish/maven")

                        ; Gradle only depends on javascript-base plugin, everything else can be removed
                        (delete-file-recursively "merged-src/src/main/java/org/gradle/plugins/javascript/coffeescript")
                        (delete-file-recursively "merged-src/src/main/java/org/gradle/plugins/javascript/envjs")
                        (delete-file-recursively "merged-src/src/main/java/org/gradle/plugins/javascript/jshint")
                        (delete-file-recursively "merged-src/src/main/java/org/gradle/plugins/javascript/rhino")

                        (for-each delete-file
                          (list
                            "merged-src/src/main/java/org/gradle/internal/nativeintegration/console/WindowsConsoleDetector.java"
                            "merged-src/src/main/java/org/gradle/internal/resource/transport/http/ApacheDirectoryListingParser.java"
                            "merged-src/src/main/java/org/gradle/plugin/devel/plugins/IvyPluginPublishingRules.java"
                            "merged-src/src/main/java/org/gradle/plugin/devel/plugins/MavenPluginPublishingRules.java"

                            ; Only used in Tooling API and tests
                            "merged-src/src/main/java/org/gradle/tooling/internal/consumer/ConnectorServices.java"
                            "merged-src/src/main/java/org/gradle/tooling/internal/consumer/DistributionFactory.java"
                            "merged-src/src/main/java/org/gradle/tooling/internal/consumer/DistributionInstaller.java"
                            "merged-src/src/main/java/org/gradle/tooling/internal/consumer/DefaultGradleConnector.java"
                            "merged-src/src/main/java/org/gradle/tooling/GradleConnector.java"
                            ))))
                    (add-before 'build 'copy-resources
                      (lambda _
                        (copy-recursively "merged-src/src/main/resources" "build/classes")))
                    (add-after 'copy-resources 'generate-build-receipt
                      (lambda _
                        (mkdir-p "build/classes/org/gradle")
                        (with-output-to-file "build/classes/org/gradle/build-receipt.properties"
                          (lambda _
                            (display
                              (string-append
                                "commitId=0000000000000000000000000000000000000000\n"
                                "buildTimestampIso=unknown\n"
                                "versionNumber=" ,version "-bootstrap-0\n"))))))
                    (add-after 'copy-resources 'generate-imports-and-mappings
                      (lambda _
                        (use-modules (ice-9 regex) (ice-9 string-fun) (srfi srfi-1))
                        (let* ((is-normal-source? (lambda (file stat)
                                                    (and
                                                      ((file-name-predicate "\\.(groovy|java)$") file stat)
                                                      (not (string-contains file "/package-info.java")))))
                                (get-package-sources-exactly-in
                                  (lambda (package-path) (find-files package-path
                                                           (lambda (file stat)
                                                             (and
                                                               ; equal is also ok as that is the '/' character added to the package-path
                                                               (<= (string-rindex file #\/) (string-length package-path))
                                                               (is-normal-source? file stat))))))
                                (get-package-sources-recursively-in
                                  (lambda (package-path) (find-files package-path is-normal-source?)))
                                (get-simple-name
                                  (lambda (path)
                                    (let* ((name-with-extension (basename path))
                                            (last-dot-index (string-rindex name-with-extension #\.)))
                                      (if last-dot-index
                                        (string-take name-with-extension last-dot-index)
                                        name-with-extension))))
                                (get-full-package-name
                                  (lambda (path)
                                    (string-replace-substring (dirname path) "/" ".")))
                                (api-sources (with-directory-excursion "merged-src/src/main/java"
                                               (filter
                                                 (lambda (path) (not (or
                                                                       (string-contains path "/internal/") ; from ext.publicApiExcludes

                                                                       ; from excludePackage entries in defaultImports task:
                                                                       (string-contains path "org/gradle/tooling/")
                                                                       (string-contains path "org/gradle/testfixtures/")
                                                                       (string-match "org/gradle/plugins/ide/eclipse/model/[^/]+" path)
                                                                       (string-match "org/gradle/plugins/ide/idea/model/[^/]+" path)
                                                                       (string-match "org/gradle/api/tasks/testing/logging/[^/]+" path)
                                                                       (string-match "org/gradle/plugins/binaries/model/[^/]+" path)
                                                                       (string-match "org/gradle/platform/base/test/[^/]+" path))))
                                                 (sort!
                                                   (append ; from ext.publicApiIncludes
                                                     (apply append (map get-package-sources-exactly-in
                                                                     (list "org/gradle"
                                                                           "org/gradle/plugin/repository"
                                                                           "org/gradle/plugin/use"
                                                                           "org/gradle/plugin/management")))
                                                     (apply append (map get-package-sources-recursively-in
                                                                     (list "org/gradle/api"
                                                                           "org/gradle/authentication"
                                                                           "org/gradle/buildinit"
                                                                           "org/gradle/caching"
                                                                           "org/gradle/concurrent"
                                                                           "org/gradle/deployment"
                                                                           "org/gradle/external/javadoc"
                                                                           "org/gradle/ide"
                                                                           "org/gradle/includedbuild"
                                                                           "org/gradle/ivy"
                                                                           "org/gradle/jvm"
                                                                           "org/gradle/language"
                                                                           "org/gradle/maven"
                                                                           "org/gradle/nativeplatform"
                                                                           "org/gradle/normalization"
                                                                           "org/gradle/platform"
                                                                           "org/gradle/play"
                                                                           "org/gradle/plugin/devel"
                                                                           "org/gradle/plugins"
                                                                           "org/gradle/process"
                                                                           "org/gradle/testfixtures"
                                                                           "org/gradle/testing/jacoco"
                                                                           "org/gradle/tooling"
                                                                           "org/gradle/model"
                                                                           "org/gradle/testkit"
                                                                           "org/gradle/testing"
                                                                           "org/gradle/vcs"
                                                                           "org/gradle/workers"))))
                                                   string<?))))
                                (api-mappings
                                  (let ((mapping-table
                                          ; To generate mappings in the same order as Gradle does, resulting alist should be sorted by path.
                                          ; However, assoc-set! adds new entries to the beginning of a list, so reverse the resulting list to
                                          ; restore the path order. Fold-right cannot be used here as it will make individual name-mapping lists
                                          ; in reversed path order.
                                          (reverse (fold
                                                     (lambda (path mapping-table)
                                                       (let* ((name (get-simple-name path))
                                                               (name-mappings (or (assoc-ref mapping-table name) '())))
                                                         (assoc-set! mapping-table
                                                           name
                                                           (append
                                                             name-mappings
                                                             (list (string-append (get-full-package-name path) "." name))))))
                                                     '()
                                                     api-sources))))
                                    (map
                                      (lambda (name-mapping)
                                        (string-append
                                          (car name-mapping) ":"
                                          (string-join (cdr name-mapping) ";")
                                          ";"))
                                      mapping-table)))
                                (default-imports (delete-duplicates (map
                                                                      (lambda (path) (string-append "import " (get-full-package-name path) ".*"))
                                                                      api-sources)))
                                (write-lines-to (lambda (path items)
                                                  (call-with-output-file path (lambda (port)
                                                                                (for-each
                                                                                  (lambda (item)
                                                                                    (display item port)
                                                                                    (newline port))
                                                                                  items))))))
                          (write-lines-to "build/classes/api-mapping.txt" api-mappings)
                          (write-lines-to "build/classes/default-imports.txt" default-imports)))))))
    (home-page "https://gradle.org/")
    (synopsis "Open-source build automation tool with an extensible declarative build language")
    (description
      "Gradle Build Tool is a fast, dependable, and adaptable open-source build automation tool with an elegant and extensible declarative build language.
      NOTE: To keep up to date with the current version of Groovy in Guix, this build backports migration to Groovy 3 from Gradle 7.0 and thus partially breaks compatibility with the upstream. To see how it may affect your scripts you can check Groovy-related sections at https://docs.gradle.org/7.0/userguide/upgrading_version_6.html#changes_to_groovy_and_groovy_dsl")
    (license license:asl2.0)))

(define gradle
  (package
    (inherit gradle-bootstrap)
    (source (origin
              (inherit (package-source gradle-bootstrap))
              (patches '("patches/gradle-4.5.1-asm.patch"
                         "patches/gradle-4.5.1-groovy-2.4.patch" "patches/gradle-4.5.1-groovy-2.5-1.patch"
                         "patches/gradle-4.5.1-groovy-2.5-2.patch" "patches/gradle-4.5.1-groovy-2.5-3.patch"
                         "patches/gradle-4.5.1-groovy-2.5-4.patch" "patches/gradle-4.5.1-groovy-3.patch"
                         "patches/gradle-4.5.1-guava.patch" "patches/gradle-4.5.1-kryo.patch"
                         "patches/gradle-4.5.1-type-inference-fix.patch" "patches/gradle-4.5.1-type-fix.patch"

                         "patches/gradle-4.5.1-default-methods.patch"
                         "patches/gradle-4.5.1-dekotlinize-build-files.patch"
                         "patches/gradle-4.5.1-local-repository.patch" "patches/gradle-4.5.1-no-remote-cache.patch"
                         "patches/gradle-4.5.1-remove-complex-dependencies.patch"
                         "patches/gradle-4.5.1-unshaded-groovy.patch"))))
    (native-inputs (list
                     java-jsoup java-pegdown zip))
    (arguments
      `(#:modules ((guix build ant-build-system) (guix build java-utils) (guix build utils) (ice-9 ftw) (srfi srfi-1)
                    (ice-9 string-fun) (srfi srfi-26))
         ,@(substitute-keyword-arguments (package-arguments gradle-bootstrap)
             ((#:phases phases) ; TODO: verify gradle and gradle-wrapper hashes against well-known ones
               `(modify-phases %standard-phases
                  ;                    (add-before 'build 'remove-src-tests
                  ;                      (lambda _ ; remove tests as they depend on groovy test classes not present in Guix
                  ;                        (delete-file-recursively "src/test")))
                  ;                    (add-before 'build 'remove-build-src-tests
                  ;                      (lambda _ ; remove tests as they depend on groovy test classes not present in Guix
                  ;                        (delete-file-recursively "buildSrc/src/test")))

                  (add-before 'build 'unshade-imports ; TODO: how to use the same lambda here and in the -bootstrap?
                    (lambda _
                      (substitute* (find-files "." ".*\\.(java|groovy)$")
                        (("groovyjarjarasm") "org.objectweb") ; no dot at the end of the pattern as otherwise it would miss some package mentions
                        (("groovyjarjarantlr") "antlr"))))
                  (add-before 'build 'patch-for-newer-guava
                    (lambda _
                      (substitute* (find-files "." ".*\\.(java|groovy)$")
                        (("import static com.google.common.collect.Iterators.emptyIterator;")
                          "import static java.util.Collections.emptyIterator;")
                        (("CharMatcher.JAVA_ISO_CONTROL") "CharMatcher.javaIsoControl()")
                        (("Iterators.emptyIterator\\(\\)") "java.util.Collections.emptyIterator()")
                        (("Objects.toStringHelper") "com.google.common.base.MoreObjects.toStringHelper"))))
                  (add-before 'build 'patch-jcip
                    (lambda _
                      (substitute* (find-files "." ".*\\.(java|groovy)$")
                        (("import net\\.jcip\\.annotations\\.((Not)?ThreadSafe;)" _ name)
                          (string-append "import javax.annotation.concurrent." name)))))
                  ;; Remove online dependencies, dependency loops and other too complex dependencies
                  (add-before 'build 'remove-complex-dependencies
                    (lambda _
                      (for-each delete-file
                        (list
                          "buildSrc/src/main/groovy/org/gradle/build/docs/CacheableAsciidoctorTask.groovy" ; depends on JRuby which is not packaged in Guix
                          "buildSrc/src/main/groovy/org/gradle/testing/DistributedPerformanceTest.groovy" ; depends on a remote CI system
                          "buildSrc/src/main/groovy/org/gradle/testing/PerformanceTest.java" ; dependends on previous versions of Gradle
                          ))
                      (delete-file-recursively "buildSrc/src/main/groovy/org/gradle/binarycompatibility") ; dependends on previous versions of Gradle
                      (delete-file-recursively "buildSrc/src/main/groovy/org/gradle/testing/performance") ; dependends on previous versions of Gradle
                      (delete-file-recursively "buildSrc/src/test") ; has dependency loops back to Gradle (spock)
                      (substitute* (find-files "." "\\.gradle$")
                        ((" crossVersionTest[A-Za-z]+ " all) (string-append "// " all)) ; dependencies for tests depending on previous versions of Gradle
                        )))
                  (add-before 'build 'generate-groovy-pom
                    (generate-pom.xml "groovy-pom.xml" "org.codehaus.groovy" "groovy" ,(package-version groovy)))
                  (add-before 'build 'patch-versions
                    (lambda _ ; TODO: implement it in init.gradle instead and limit to the same major version
                      (substitute* "gradle/dependencies.gradle"
                        (("(com.google.guava:)guava-jdk5:([0-9][0-9.]+)([:'@\"])" _ prefix version suffix)
                          (string-append prefix "guava:[" version ",)" suffix))
                        (("((org.ow2.asm:asm[^'\":]+|com.google.code.findbugs:jsr305):)([0-9]+[0-9.]*)([:'@\"])" _ prefix _ version suffix)
                          (string-append prefix "[" version ",)" suffix))
                        (("net.jcip:jcip-annotations:([0-9][0-9.]+)([:'@\"])" _ _ suffix)
                          (string-append "com.google.code.findbugs:jsr305:[3,)" suffix))
                        (("(org.fusesource.jansi:jansi:)([0-9][0-9.]+)([:'@\"])" _ prefix _ suffix) ; TODO update the package instead
                          (string-append prefix "[1.16,2)" suffix))
                        (("([:'\"])([0-9]+)([0-9.]*)([:'@\"])" _ prefix major-version rest-version suffix)
                          (string-append prefix "["
                            major-version rest-version ", "
                            (number->string (1+ (string->number major-version))) ")"
                            suffix)))

                      (substitute* '("buildSrc/build.gradle"
                                      "subprojects/docs/docs.gradle"
                                      "subprojects/docs/src/transforms/release-notes.gradle"
                                      "subprojects/reporting/reporting.gradle")
                        (("(com.google.guava:)guava-jdk5:([0-9][0-9.]+)([:'@\"])" _ prefix version suffix)
                          (string-append prefix "guava:[" version ",)" suffix))
                        (("((org.ow2.asm:asm[^'\":]+|com.google.code.findbugs:jsr305):)([0-9]+[0-9.]*)([:'@\"])" _ prefix _ version suffix)
                          (string-append prefix "[" version ",)" suffix))
                        (("net.jcip:jcip-annotations:([0-9][0-9.]+)([:'@\"])" _ _ suffix)
                          (string-append "com.google.code.findbugs:jsr305:[3,)" suffix))
                        (("(:)([0-9]+)([0-9.]*)([:'@\"])" _ prefix major-version rest-version suffix)
                          (string-append prefix "["
                            major-version rest-version ", "
                            (number->string (1+ (string->number major-version))) ")"
                            suffix)))))

                  ;; This phase ensures any .gradle.kts not in the dekotlinize patch fails the build
                  (add-before 'build 'rename-kts-build-files
                    (lambda _
                      (for-each
                        (lambda (f)
                          (rename-file
                            f
                            (string-drop-right f 4)))
                        (find-files "." ".*\\.gradle\\.kts"))))
                  (replace 'build
                    (lambda* (#:key inputs outputs #:allow-other-keys)
                      (let* ((dir (string-append (getenv "TMP") "/build-home"))
                              (m2-packages (filter
                                             (lambda (input)
                                               (file-exists? (string-append (cdr input) "/lib/m2")))
                                             inputs))
                              (m2-roots (map
                                          (lambda (input) (string-append (cdr input) "/lib/m2"))
                                          m2-packages)))
                        (mkdir-p (string-append dir "/.m2/repository"))
                        (for-each
                          (lambda (m2-root)
                            (copy-recursively
                              m2-root
                              (string-append dir "/.m2/repository")))
                          m2-roots)

                        (use-modules (ice-9 regex)) ; for string-match
                        (let* (
                                (mavenize-package (lambda (pkg version group name source-path)
                                                    (let* ((source-extension-with-dot (string-drop
                                                                                        source-path
                                                                                        (string-rindex source-path #\.)))
                                                            (groupPath (string-replace-substring group "." "/"))
                                                            (path
                                                              (string-append
                                                                dir "/.m2/repository/"
                                                                groupPath "/" name "/" version "/"
                                                                name "-" version source-extension-with-dot)))
                                                      (mkdir-p (dirname path))
                                                      (symlink (string-append pkg source-path) path)
                                                      path)))

                                (groovyLocalMavenPath
                                  (mavenize-package ,groovy ,(package-version groovy)
                                    "org.codehaus.groovy" "groovy" "/lib/groovy.jar"))
                                (antlrMavenPath (mavenize-package ,antlr2 ,(package-version antlr2)
                                  "antlr" "antlr" "/lib/antlr.jar"))
                                (asmMavenPath
                                  (mavenize-package ,java-asm-9 ,(package-version java-asm-9)
                                    "org.ow2.asm" "asm" "/share/java/asm9.jar"))
                                (asmCommonsMavenPath
                                  (mavenize-package ,java-asm-commons-9 ,(package-version java-asm-commons-9)
                                    "org.ow2.asm" "asm-commons" "/share/java/asm-commons8.jar"))
                                (asmTreeMavenPath
                                  (mavenize-package ,java-asm-tree-9 ,(package-version java-asm-tree-9)
                                    "org.ow2.asm" "asm-tree" "/share/java/asm-tree.jar"))

                                (classpathWithoutAntlrAsm
                                  (string-join
                                    (filter
                                      (lambda (path) (and
                                                       (not (string-match ".*[^[:alpha:]]asm[^[:alpha:]].*" path))
                                                       (not (string-match ".*/antlr\\.jar$" path))))
                                      (string-split (getenv "CLASSPATH") #\:))
                                    ":")))

                          (substitute* (find-files
                                         (string-append dir "/.m2/repository/com/google/guava")
                                         "\\.pom$")
                            ((">[[:digit:].]+-android<") (string-append ">" ,(package-version java-guava) "-jre<")))

                          (mavenize-package ,ant ,(package-version ant)
                            "org.apache.ant" "ant" "/lib/ant.jar")
                          ; TODO: fix the package instead?
                          (mavenize-package ,java-commons-collections ,(package-version java-commons-collections)
                            "commons-collections" "commons-collections"
                            (string-append "/share/java/commons-collections-" ,(package-version java-commons-collections) ".jar"))
                          (mavenize-package ,java-commons-lang ,(package-version java-commons-lang)
                            "commons-lang" "commons-lang"
                            (string-append "/share/java/commons-lang-" ,(package-version java-commons-lang) ".jar"))
                          (mavenize-package ,java-kryo-2 ,(package-version java-kryo-2)
                            "com.esotericsoftware.kryo" "kryo" "/share/java/kryo.jar")
                          (mavenize-package ,java-gson ,(package-version java-gson)
                            "com.google.code.gson" "gson" "/share/java/gson.jar")
                          (mavenize-package ,java-jhighlight ,(package-version java-jhighlight)
                            "com.uwyn" "jhighlight" "/share/java/jhighlight.jar")
                          (mavenize-package ,java-native-platform-0.14 ,(package-version java-native-platform-0.14)
                            "net.rubygrapefruit" "native-platform" "/share/java/native-platform.jar")
                          (mavenize-package ,java-jsoup ,(package-version java-jsoup)
                            "org.jsoup" "jsoup" "/share/java/jsoup.jar")
                          (mavenize-package ,r-jquerylib "1.12.4" ; TODO: replace with a new js-jquery package
                            "jquery" "jquery.min" "/site-library/jquerylib/lib/1.12.4/jquery-1.12.4.min.js")

                          ; TODO: fix java-guava package instead
                          (with-directory-excursion dir
                            (mkdir-p "empty-dir")
                            (with-directory-excursion "empty-dir"
                              (invoke "zip" "-r"
                                (string-append
                                  dir
                                  "/.m2/repository/com/google/guava/listenablefuture/9999.0-empty-to-avoid-conflict-with-guava/listenablefuture-9999.0-empty-to-avoid-conflict-with-guava.jar")
                                "."
                                "-i" "*")))
                          
                          (let* ((version ,(package-version docbook-xsl))
                                  (name "docbook-xsl")
                                  (groupPath "docbook")
                                  (path
                                    (string-append
                                      dir "/.m2/repository/"
                                      groupPath "/" name "/" version "/"
                                      name "-" version ".zip")))
                            (mkdir-p (dirname path))
                            (with-directory-excursion (string-append ,docbook-xsl "/xml/xsl/docbook-xsl-" version)
                              (invoke "zip" "-0oyR"
                                path
                                "*")))

                          (let* ((version "1.11")
                                  (name "fusesource-pom")
                                  (groupPath "org/fusesource")
                                  (path
                                    (string-append
                                      dir "/.m2/repository/"
                                      groupPath "/" name "/" version "/"
                                      name "-" version ".pom")))
                            (mkdir-p (dirname path))
                            (symlink   ; TODO: fix java-jansi instead
                              ,(origin
                                 (method url-fetch)
                                 (uri "https://github.com/fusesource/mvnplugins/raw/1009400af302fdea72ea234df9360aabe4921eb3/fusesource-pom/pom.xml")
                                 (sha256 (base32 "1vnbj9gc9qgs73lvna9n102m41qk82flc7ccri2sd2j5ssj9r516")))
                              path))

                          (setenv "CLASSPATH"
                            (string-append
                              asmMavenPath ":" asmCommonsMavenPath ":" asmTreeMavenPath ; Only the correct version of ASM must be on the classpath
                              ":" antlrMavenPath
                              ":" groovyLocalMavenPath ; Groovy version detection only accepts Maven-like file names, so add a mavenized copy to the beginning
                              ":" classpathWithoutAntlrAsm
                              ":" ,gradle-bootstrap "/share/java/gradle.jar"))
                          (setenv "HOME" dir)
                          (invoke
                            "java"
                            (string-append "-Duser.home=" dir)
                            "-Dorg.gradle.daemon=false"
                            "org.gradle.launcher.Main"
                            "--init-script" "init.gradle"
                            "--no-build-cache"
;                            "--offline"
                            "--stacktrace"
                            "-x" "check"
                            "install" (string-append "-Pgradle_installPath=" (assoc-ref outputs "out"))
                          )))))
                  (delete 'reorder-jar-content)
                  (delete 'generate-jar-indices))))))))

;gradle-bootstrap
gradle