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
  #:use-module (gnu packages javascript)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages maven)
  #:use-module (gnu packages maven-parent-pom)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages web)
  #:use-module (guix build utils)
  #:use-module (guix build-system ant)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system maven)
  #:use-module (guix git-download)
  #:use-module (guix svn-download))

; TODO: ensure all packages here reproducible

(define groovy-test  ; TODO: make the package public instead
  (module-ref (resolve-module '(gnu packages groovy)) 'groovy-test))

(define java-plexus-containers-parent-pom-1.7 ; TODO: add this dependency to java-plexus-container-default-1.7 instead?
  (module-ref (resolve-module '(gnu packages java)) 'java-plexus-containers-parent-pom-1.7))
(define make-apache-commons-parent-pom ; TODO: add this dependency to the relevant package?
  (module-ref (resolve-module '(gnu packages maven-parent-pom)) 'make-apache-commons-parent-pom))

(define-public apache-commons-parent-pom-42
  (make-apache-commons-parent-pom
    "42" "1x7hpi2zwibfd73ixwabg86qywn9s999a6rbsay28lwg2yp9ldng"
    apache-parent-pom-18))

;(define maven-pom
;  (module-ref (resolve-module '(gnu packages maven)) 'maven-pom))
;(define make-maven-parent-pom
;  (module-ref (resolve-module '(gnu packages maven-parent-pom)) 'make-maven-parent-pom))
;(define-public maven-parent-pom-23
;  (let ((base (make-maven-parent-pom
;                "23" "0sjzbk60idz65km38nphcllrdkrjv4zzzhm7pl6429lfk3kpc3wf"
;                apache-parent-pom-13
;                #:replacements
;                (delay
;                  `(("org.codehaus.plexus"
;                      ("plexus-component-annotations" .
;                        ,(package-version java-plexus-container-default))))))))
;    (package
;      (inherit base)
;      (arguments
;        (substitute-keyword-arguments (package-arguments base)
;          ((#:phases phases)
;            `(modify-phases ,phases
;               (delete 'install-plugins)
;               (delete 'install-shared))))))))
;(define maven-3.0.5-pom
;  (package
;    (inherit maven-pom)
;    (version "3.0.5")
;    (source (origin
;              (method git-fetch)
;              (uri (git-reference
;                     (url "https://github.com/apache/maven")
;                     (commit (string-append "maven-" version))))
;              (file-name (git-file-name "maven" version))
;              (sha256
;                (base32
;                  "1bvk3r5vlax1shxp6nis0628ls9grdiz0fchsljaxcp9z0a2y0sd"))
;              (modules '((guix build utils)))
;              (snippet
;                '(begin
;                   (for-each delete-file (find-files "." "\\.jar$"))
;                   (for-each (lambda (file) (chmod file #o644))
;                     (find-files "." "."))
;                   #t))
;              (patches
;                (search-patches "maven-generate-component-xml.patch"
;                  "maven-generate-javax-inject-named.patch"))))
;    (propagated-inputs
;      (list maven-parent-pom-23))))
;; TODO: also replace inputs
;(define maven-3.0.5-model
;  (package
;    (inherit maven-3.0-model)
;    (version (package-version maven-3.0.5-pom))
;    (source (package-source maven-3.0.5-pom))))
;(define maven-3.0.5-compat
;  (package
;    (inherit maven-3.0-compat)
;    (version (package-version maven-3.0.5-pom))
;    (source (package-source maven-3.0.5-pom))))
(define-public java-sonatype-aether-impl-1.13
  (package
    (inherit java-sonatype-aether-api-1.13)
    (name "java-sonatype-aether-impl")
    (source
      (origin
        (inherit (package-source java-sonatype-aether-api-1.13))
        (patches (append
                   (origin-patches (package-source java-sonatype-aether-api-1.13))
                   '("patches/java-sonatype-aether-impl-1.13-test-fix.patch")))))
    (arguments
      `(#:jar-name "aether-impl.jar"
         #:source-dir "aether-impl/src/main/java"
         #:test-dir "aether-impl/src/test"
         #:phases
         (modify-phases %standard-phases
           (add-before 'install 'fix-pom
             (lambda _
               (substitute* "aether-impl/pom.xml"
                 (("org.sonatype.sisu") "org.codehaus.plexus")
                 (("sisu-inject-plexus") "plexus-container-default"))
               #t))
           (add-after 'build 'generate-metadata
             (lambda _
               (invoke "java" "-cp" (string-append (getenv "CLASSPATH") ":build/classes")
                 "org.codehaus.plexus.metadata.PlexusMetadataGeneratorCli"
                 "--source" "src/main/java"
                 "--output" "build/classes/META-INF/plexus/components.xml"
                 "--classes" "build/classes"
                 "--descriptors" "build/classes/META-INF")
               #t))
           (add-after 'generate-metadata 'rebuild
             (lambda _
               (invoke "ant" "jar")
               #t))
           (replace 'install (install-from-pom "aether-impl/pom.xml")))))
    (propagated-inputs
      `(("java-sonatype-aether-api" ,java-sonatype-aether-api-1.13)
        ("java-sonatype-aether-spi" ,java-sonatype-aether-spi-1.13)
        ("java-sonatype-aether-util" ,java-sonatype-aether-util-1.13)
        ("java-plexus-component-annotations" ,java-plexus-component-annotations)
        ("java-plexus-container-default" ,java-plexus-container-default)
        ("java-slf4j-api" ,java-slf4j-api)))
    (native-inputs
      (list java-junit java-plexus-component-metadata
            java-sonatype-aether-test-util-1.13))))

(define groovy-spock-core
  (package
    (name "groovy-spock-core")
    (version "2.3")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/spockframework/spock/archive/refs/tags/spock-" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "0jv36c54r5c7yqbjp7pmh2773h97gcvfa6b3wyf3js74ra99f1rp"))
        (modules '((guix build utils)))
        (patches '("patches/groovy-spock-core-patch-underscore.patch"))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list groovy-ant-patched java-jetbrains-annotations java-asm-8 java-byte-buddy-dep java-cglib
                         java-junit-platform-testkit-5 java-objenesis))
    (propagated-inputs (list groovy java-geantyref-1 java-hamcrest-all))
    (arguments
      `(#:jar-name "spock-core.jar"
         #:jdk ,openjdk9
         #:source-dir "spock-core/src/main"
         #:tests? #f  ; this module doesn't have tests. TODO: run tests from spock-testkit
         #:phases (modify-phases %standard-phases ; TOOD: use groovy compiler
                    (add-before 'build 'patch-build.xml
                      (lambda _
                        (substitute* "build.xml"
                          (("<javac ([^>]+)>" all args) (string-append
                                                          "<taskdef name=\"groovyc\" classname=\"org.codehaus.groovy.ant.Groovyc\" classpathref=\"classpath\"/>"
                                                          "<groovyc " args " fork=\"true\"><classpath refid=\"classpath\"/>"
                                                          "<javac debug=\"true\" " args ">"))
                          (("</javac>" all) (string-append all "</groovyc>")))))
                    (add-after 'build 'build-resources
                      (lambda _
                        (substitute* (find-files "spock-core/src/main/resources" ".*")
                          (("@version@") ,version)
                          (("@minGroovyVersion@") "3.0.0")
                          (("@maxGroovyVersion@") "3.9.99")) ; TODO: compute from groovy version
                        (copy-recursively "spock-core/src/main/resources" "build/classes")))
                    (add-before 'install 'generate-pom.xml
                      (generate-pom.xml "pom.xml"
                        "org.spockframework"
                        "spock-core"
                        (string-append ,version "-groovy-3.0"))) ; TODO: compute from groovy version
                    (replace 'install
                      (install-from-pom "pom.xml")))))
    (home-page "https://spockframework.org/")
    (synopsis "BDD-style developer testing and specification framework for Java and Groovy applications.
     This is the core framework module - the only mandatory module.")
    (description "Spock is a testing and specification framework for Java and Groovy applications.
     What makes it stand out from the crowd is its beautiful and highly expressive specification language.
      Thanks to its JUnit runner, Spock is compatible with most IDEs, build tools, and continuous integration servers.")
    (license license:asl2.0)))

(define groovy-spock-junit4
  (package
    (inherit groovy-spock-core)
    (propagated-inputs (list java-junit groovy-spock-core))
    (arguments
      `(#:jar-name "spock-junit4.jar"
        #:jdk ,openjdk9
        #:source-dir "spock-junit4/src/main"
        #:tests? #f  ; TODO
        #:phases (modify-phases %standard-phases
                   (add-before 'build 'patch-build.xml
                     (lambda _
                       (substitute* "build.xml"
                         (("<javac ([^>]+)>" all args) (string-append
                                                         "<taskdef name=\"groovyc\" classname=\"org.codehaus.groovy.ant.Groovyc\" classpathref=\"classpath\"/>"
                                                         "<groovyc " args " fork=\"true\"><classpath refid=\"classpath\"/>"
                                                         "<javac debug=\"true\" " args ">"))
                         (("</javac>" all) (string-append all "</groovyc>")))))
                   (add-after 'build 'copy-resources
                     (lambda _
                       (copy-recursively "spock-junit4/src/main/resources" "build/classes")))
                   (add-before 'install 'generate-pom.xml
                     (generate-pom.xml "pom.xml"
                       "org.spockframework"
                       "spock-junit4"
                       (string-append ,(package-version groovy-spock-core) "-groovy-3.0"))) ; TODO: compute from groovy version
                   (replace 'install
                     (install-from-pom "pom.xml")))))
    (synopsis "BDD-style developer testing and specification framework for Java and Groovy applications.
     This package provides the module for JUnit 4.")))

(define-public java-apiguardian
  (package
    (name "java-apiguardian")
    (version "1.1.2")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/apiguardian-team/apiguardian/archive/refs/tags/r" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "1v3hx78gbhvri2n5v7cgc1spszz10ghd6iapx258c0gkn9l5hrar"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (arguments
      `(#:jar-name "apiguardian.jar"
        #:source-dir "src/main/java"
         #:tests? #f)) ; no tests in the project
    (home-page "https://apiguardian-team.github.io/apiguardian/docs/current/api/")
    (synopsis "Java annotation for documenting the @API status of types and members in Java APIs. Maintained by the JUnit team.")
    (description "Library that provides the @API annotation that is used to annotate public types, methods, constructors,
     and fields within a framework or application in order to publish their status and level of stability and to indicate
      how they are intended to be used by consumers of the API.")
    (license license:asl2.0)))

(define java-assertj-new ; TODO: update the inherited package
  (package
    (inherit java-assertj)
    (version "3.27.6")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                     (url "https://github.com/assertj/assertj")
                     (commit (string-append "assertj-build-" version))))
              (file-name (git-file-name (package-name java-assertj) version))
              (sha256 (base32 "13zs88wblk71kqz1g6j71mybabqibcms7p1pl5fkjyb4w7baz6la"))))
    (propagated-inputs (list java-byte-buddy-dep java-junit-jupiter-java-api-5))
    (arguments
      `(,@(substitute-keyword-arguments (package-arguments java-assertj)
        ((#:source-dir _) "assertj-core/src/main/java"))))))

; Avoid pack200 as it depends on old version of ASM library
(define java-commons-compress-no-pack200 ; TODO: patch dependent package instead
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

(define java-jte-runtime
  (package
    (name "java-jte-runtime")
    (version "3.2.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/casid/jte/archive/refs/tags/" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "1sp31cmj9vn4d933vvdqg6ibv1ixvndrhawyr4m4amkh9nh3cdsf"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (arguments
      `(#:jar-name "java-jte-runtime.jar"
        #:jdk ,openjdk17
        #:tests? #f ; circular dependency on JUnit Jupiter and AssertJ
        #:source-dir "jte-runtime/src/main/java"
        #:phases (modify-phases %standard-phases
                   (replace 'install
                     (install-from-pom "jte-runtime/pom.xml")))))
    (home-page "https://jte.gg")
    (synopsis "Secure and speedy templates for Java and Kotlin. This package provides the runtime")
    (description "Designed to introduce as few new keywords as possible and builds upon existing language features,
     making it straightforward to reason about what a template does.")
    (license license:asl2.0)))

(define java-jte-extension-api
  (package
    (inherit java-jte-runtime)
    (name "java-jte-extension-api")
    (propagated-inputs (list java-jte-runtime))
    (arguments
      `(#:jar-name "java-jte-runtime.jar"
        #:jdk ,openjdk17
        #:tests? #f ; this module has no tests
        #:source-dir "jte-extension-api/src/main/java"
        #:phases (modify-phases %standard-phases
                   (replace 'install
                     (install-from-pom "jte-extension-api/pom.xml")))))
    (synopsis "Secure and speedy templates for Java and Kotlin. This package provides the extension API")))

(define java-jte
  (package
    (inherit java-jte-runtime)
    (name "java-jte")
    (propagated-inputs (list java-jte-extension-api java-jte-runtime))
    (arguments
      `(#:jar-name "java-jte.jar"
        #:jdk ,openjdk17
        #:tests? #f ; TODO
        #:source-dir "jte/src/main/java"
        #:phases (modify-phases %standard-phases
                   (replace 'install
                     (install-from-pom "jte/pom.xml")))))
    (synopsis "Secure and speedy templates for Java and Kotlin")))

(define java-junit-platform-commons-5 ; TODO: should it be java-junit-5-platform-commons instead?
  (package
    (name "java-junit-platform-commons")
    (version "5.14.1")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/junit-team/junit-framework/archive/refs/tags/r" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "0k2xb9ym5lf18cyw7g9iif9s5an4cwg82ik9by8316xi7ccvq53n"))
        (modules '((guix build utils)))
        (patches '("patches/java-junit-jupiter-java-api-5.14.1.patch"))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system) ; Repackage with Gradle once we have it and Kotlin in Guix?
    (propagated-inputs (list java-apiguardian))
    (arguments
      `(#:jar-name "junit-platform-commons.jar"
        #:source-dir "junit-platform-commons/src/main/java" ; TODO: build java9 dir separately with jdk9
        #:tests? #f ; TODO
        ))
    (home-page "https://junit.org/")
    (synopsis "The programmer-friendly testing framework for Java and the JVM. This is JUnit Platform Commons module.")
    (description "Unlike previous versions of JUnit, JUnit 5 is composed of several different modules from three different sub-projects.
    JUnit 5 = JUnit Platform + JUnit Jupiter + JUnit Vintage
    - The JUnit Platform serves as a foundation for launching testing frameworks on the JVM.
    - JUnit Jupiter is the combination of the programming model and extension model for writing tests and extensions in JUnit 5.
    - JUnit Vintage provides a TestEngine for running JUnit 3 and JUnit 4 based tests on the platform.")
    (license license:epl2.0)))

(define java-junit-jupiter-java-api-5
  (package
    (inherit java-junit-platform-commons-5)
    (name "java-junit-jupiter-java-api")
    (native-inputs (list java-fasterxml-jackson-annotations java-fasterxml-jackson-core java-fasterxml-jackson-databind
                         java-fasterxml-jackson-dataformat-yaml java-jte java-snakeyaml))
    (propagated-inputs (list java-junit-platform-commons-5 java-opentest4j))
    (arguments
      `(#:jar-name "junit-jupiter-api.jar"
        #:source-dir "junit-jupiter-api/src/main/java"
        #:tests? #f ; TODO
        #:phases (modify-phases %standard-phases
           (add-before 'build 'generate-classes
             (lambda _
               (mkdir-p "generator")
               (copy-file "gradle/base/code-generator-model/src/main/resources/jre.yaml" "generator/jre.yaml")
               (invoke (string-append ,(gexp-input openjdk17 "jdk") "/bin/javac")
                 "-cp" (getenv "CLASSPATH")
                 "-g"
                 "-d" "generator"
                 "gradle/plugins/code-generator/src/main/kotlin/junitbuild/generator/GenerateJreRelatedSourceCode.java"
                 "gradle/base/code-generator-model/src/main/kotlin/junitbuild/generator/model/JRE.java")
               (invoke (string-append ,(gexp-input openjdk17 "jdk") "/bin/java")
                 "-cp" (string-append (getenv "CLASSPATH")
                                      ":generator")
                 "junitbuild.generator.GenerateJreRelatedSourceCode"
                 "junit-jupiter-api/src/templates/resources/main"
                 "junit-jupiter-api/src/main/java"
                 "gradle/config/spotless/eclipse-public-license-2.0.java"))))))
    (synopsis "The programmer-friendly testing framework for Java and the JVM. This module provides JUnit Jupiter Java API.")))

(define java-junit-platform-engine-5
  (package
    (inherit java-junit-platform-commons-5)
    (name "java-junit-platform-engine")
    (propagated-inputs (list java-junit-platform-commons-5 java-opentest4j))
    (arguments
      `(#:jar-name "junit-platform-engine.jar"
        #:source-dir "junit-platform-engine/src/main"
        #:tests? #f ; TODO
        #:phases (modify-phases %standard-phases
           (add-before 'build 'copy-resources
             (lambda _
               (copy-recursively "junit-platform-engine/src/main/resources" "build/classes"))))))
    (synopsis "The programmer-friendly testing framework for Java and the JVM. This module provides JUnit Platform Engine API.")))

(define java-junit-platform-launcher-5
  (package
    (inherit java-junit-platform-commons-5)
    (name "java-junit-platform-launcher")
    (propagated-inputs (list java-junit-platform-engine-5))
    (arguments
      `(#:jar-name "junit-platform-launcher.jar"
        #:source-dir "junit-platform-launcher/src/main"
        #:tests? #f ; TODO
        #:phases (modify-phases %standard-phases
           (add-before 'build 'copy-resources
             (lambda _
               (copy-recursively "junit-platform-launcher/src/main/resources" "build/classes"))))))
    (synopsis "The programmer-friendly testing framework for Java and the JVM. This module provides JUnit Platform Engine API.")))

(define java-junit-platform-testkit-5
  (package
    (inherit java-junit-platform-commons-5)
    (name "java-junit-platform-testkit")
    (propagated-inputs (list java-assertj-new java-junit-platform-launcher-5))
    (arguments
      `(#:jar-name "junit-platform-testkit.jar"
        #:source-dir "junit-platform-testkit/src/main"
        #:tests? #f ; TODO
        ))
    (synopsis "The programmer-friendly testing framework for Java and the JVM. This module is JUnit Platform Test Kit.")))

(define-public java-minlog
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

(define java-geantyref-1
  (package
    (name "java-geantyref")
    (version "1.3.16")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/leangen/geantyref/archive/refs/tags/geantyref-v" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "0021vyfb05n8qzq501f7rvqa6wbcwz7ks23cch1bngn256qq5mzx"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-junit))
    (arguments
      `(#:jar-name "geantyref.jar"
        #:tests? #f ; TODO
        #:phases (modify-phases %standard-phases
                   (add-before 'build 'backport-instanceof
                     (lambda _
                       (substitute* (find-files "." "\\.java$")
                         (("\\(([a-z0-9_]+) instanceof ([A-Za-z0-9_<>?]+) ([a-z0-9_]+)(\\) \\{)"
                            _ variable type new-variable suffix)
                           (string-append "(" variable " instanceof " type suffix
                             type " " new-variable " = (" type ") " variable ";")))))
                   (replace 'install
                     (install-from-pom "pom.xml")))))
    (home-page "https://github.com/leangen/geantyref")
    (synopsis "Advanced generic type reflection library with support for working with AnnotatedTypes (for Java 8+)")
    (description "This library aims to provide a simple way to analyse generic type information and dynamically create (Annotated)Type instances, all at runtime.
    A fork of the excellent GenTyRef library, adding support for working with AnnotatedTypes introduced in Java 8 plus many nifty features.")
    (license license:asl2.0)))

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
    (propagated-inputs (list java-sonatype-oss-parent-pom-5))
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

(define-public java-jcifs
  (package
    (name "java-jcifs")
    (version "1.3.19")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://www.jcifs.org/src/jcifs-" version ".tgz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "19kzac3c19j0fyssibcj47868k8079wlj9azgsd7i6yqmdgqyk3y"))
        (patches '("patches/jcifs-1.3.19-fix-compile-target.patch"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(gz|jar|tar|tgz|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-javaee-servletapi))
    (arguments
      `(#:tests? #f ; no tests in the package
        #:phases (modify-phases %standard-phases
                   (add-before 'build 'generate-pom
                     (generate-pom.xml "pom.xml" "jcifs" "jcifs" ,version))
                   (replace 'install
                     (install-from-pom "pom.xml")))))
    (home-page "https://www.jcifs.org/")
    (synopsis "A client library that implements the CIFS/SMB networking protocol in 100% Java.
     CIFS is the standard file sharing protocol on the Microsoft Windows platform (e.g. Map Network Drive ...).")
    (description "Beware, JCIFS has been in maintenance-mode-only for several years and although what it does support
     works fine (SMB1, NTLMv2, midlc, MSRPC and various utility classes), jCIFS does not support the newer SMB2/3
     variants of the SMB protocol which is becoming required in newer systems. And SMB1 has been deprecated in some
     of them. So if SMB1 is disabled on your network, JCIFS' file related operations will NOT work.")
    (license license:lgpl2.1+)))

(define java-jhighlight
  (package
    (name "java-jhighlight")
    (version "1.1.0")
    (source
      (origin
        (method url-fetch) ; TODO: replace with SVN checkout from SF
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

(define-public java-simple-web-4
  (package
    (name "java-simple-web")
    (version "4.1.21")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/simpleweb/simpleweb/" version "/simple-" version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256 (base32 "049nfqmlgdpkki03n4iyc53fpbwlfkk1znjk4jj1xpvf1nw3zlrn"))
              (patches '("patches/java-simple-web-4.1.21-fix-tests.patch"))))
    (build-system ant-build-system)
    (arguments
      `(#:build-target "build"
        #:test-target "test"
        #:phases
        (modify-phases %standard-phases
          (add-after 'unpack 'remove-jars
            (lambda _
              (delete-file-recursively "jar")))
          (add-before 'install 'generate-pom
            (generate-pom.xml "pom.xml" "org.simpleframework" "simple" ,version))
          (replace 'install (install-from-pom "pom.xml")))))
    (native-inputs
      (list unzip))
    (home-page "https://simpleweb.sourceforge.net/")
    (synopsis "Web framework for Java")
    (description "The goal of Simple is to bring the power of simplicity to the world of server side Java.
     The primary focus of the project is to provide a truly embeddable Java based HTTP engine capable of handling
     enormous loads. Simple provides a truly asynchronous service model, request completion is driven using an internal,
     transparent, monitoring system.")
    (license license:asl2.0)))

(define java-jcl-over-slf4j
  (package
    (inherit java-slf4j-api)
    (name "java-jcl-over-slf4j")
    (build-system ant-build-system)
    (propagated-inputs (list java-slf4j-api))
    (native-inputs (list java-junit java-commons-logging-minimal java-slf4j-jdk14))
    (arguments
      `(#:jar-name "jcl-over-slf4j.jar"
         #:source-dir "jcl-over-slf4j/src/main"
         #:test-dir  "jcl-over-slf4j/src/test"
         #:phases ,#~(modify-phases %standard-phases
                       (add-after 'build 'copy-resources
                         (lambda _
                           (copy-recursively "jcl-over-slf4j/src/main/resources" "build/classes")))
                       (replace 'install
                         (install-from-pom "jcl-over-slf4j/pom.xml")))))
    (synopsis "JCL 1.2 implemented over SLF4J")
    (license license:asl2.0)))

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

(define java-log4j-over-slf4j
  (package
    (inherit java-slf4j-api)
    (name "java-log4j-over-slf4j")
    (build-system ant-build-system)
    (propagated-inputs (list java-slf4j-api))
    (native-inputs (list java-junit java-log4j-api java-slf4j-jdk14))
    (arguments
      `(#:jar-name "log4j-over-slf4j.jar"
         #:source-dir "log4j-over-slf4j/src/main"
         #:test-dir  "log4j-over-slf4j/src/test"
         #:phases ,#~(modify-phases %standard-phases
                         (add-after 'build 'copy-resources
                           (lambda _
                             (copy-recursively "log4j-over-slf4j/src/main/resources" "build/classes")))
                         (replace 'install
                           (install-from-pom "log4j-over-slf4j/pom.xml")))))
    (home-page "http://www..slf4j.org/log4j-over-slf4j.html")
    (synopsis "Log4j Implemented Over SLF4J")))

(define java-slf4j-jdk14
  (package
    (inherit java-slf4j-api)
    (name "java-slf4j-jdk14")
    (build-system ant-build-system)
    (propagated-inputs (list java-slf4j-api))
    (native-inputs (list java-junit))
    (arguments
      `(#:jar-name "slf4j-jdk14.jar"
         #:source-dir "slf4j-jdk14/src/main"
         #:test-dir  "slf4j-jdk14/src/test"
         #:tests? #f ; TODO
         #:phases ,#~(modify-phases %standard-phases
                       (add-after 'build 'copy-resources
                         (lambda _
                           (copy-recursively "slf4j-jdk14/src/main/resources" "build/classes")))
                       (add-before 'check 'copy-helpers
                         (lambda _
                           (copy-recursively "slf4j-api/src/test/java" "slf4j-jdk14/src/test/java")))
                       (replace 'install
                         (install-from-pom "slf4j-jdk14/pom.xml")))))
    (home-page "https://www.slf4j.org/api/org/slf4j/jul/JDK14LoggerAdapter.html")
    (synopsis "Binding/provider for java.util.logging, also referred to as JDK 1.4 logging")
    (license license:expat)))

(define java-opentest4j
  (package
    (name "java-opentest4j")
    (version "1.3.0")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/ota4j-team/opentest4j/archive/refs/tags/r" version ".tar.gz"))
        (file-name (string-append name "-" version ".tar.gz"))
        (sha256 (base32 "1d3czx8y0iyrw3gj8gqk0pxs4ik5jyh0wjln6wg2awzcr0i9jzwd"))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (build-system ant-build-system)
    (native-inputs (list java-junit))
    (arguments
      `(#:jar-name "opentest4j.jar"
        #:jdk ,openjdk10
        #:source-dir "src/main/java"
        #:phases (modify-phases %standard-phases 
                   (add-before 'build 'patch-build.xml
                     (lambda _ ; tests require JDK10+, but the output jar should be compatible with JDK1.6
                       (substitute* "build.xml"
                         (("(<javac ([^>]+)srcdir=\"src/main/java\"([^>]+))>" _ prefix)
                           (string-append prefix " release=\"6\">"))))))))
    (home-page "https://github.com/ota4j-team/opentest4j")
    (synopsis "Common Java exception classes to represent test failures. Maintained by the JUnit team.")
    (description "The primary goal of the project is to enable testing frameworks like JUnit, TestNG, Spock, etc. and
     third-party assertion libraries like Hamcrest, AssertJ, etc. to use a common set of exceptions that IDEs and build
     tools can support in a consistent manner across all testing scenarios -- for example, for consistent handling of
     failed assertions and failed assumptions as well as visualization of test execution in IDEs and reports.
     Currently there is a small set of errors and exceptions that is considered to be common for all testing and
     assertion frameworks.")
    (license license:asl2.0)))

(define java-sonatype-oss-parent-pom-5
  (hidden-package
    (package
      (inherit java-sonatype-oss-parent-pom-7)
      (version "5")
      (source (origin
                (method git-fetch)
                (uri (git-reference
                       (url "https://github.com/sonatype/oss-parents")
                       (commit (string-append "oss-parent-" version))))
                (sha256
                  (base32
                    "1zr506sfkhb9nxkzqsmdii6yy7fiw1rwd06zaclxxxyqlzlv6q17")))))))

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

(define java-nekohtml
  (package
    (name "java-nekohtml")
    (version "1.9.22")
    (source
      (origin
        (method svn-fetch)
        (uri (svn-reference
               (url "https://svn.code.sf.net/p/nekohtml/code/trunk/")
               (revision 349)))
        (file-name (git-file-name name version))
        (sha256
          (base32 "1gj1s0bbzsvnl3lwbhd706fi1i9l48aar9xnb7mw3v8w0nyan3j6"))
        (patches '("patches/nekohtml-fix-tests.patch" "patches/nekohtml-xerces-latest.patch"))
        (modules '((guix build utils)))
        (snippet '(delete-file-recursively "lib"))))
    (build-system ant-build-system)
    (native-inputs (list java-junit java-jaxp))
    (propagated-inputs (list java-xerces))
    (arguments
      `(#:test-target "test"
        #:phases (modify-phases %standard-phases
                      (add-before 'build 'provide-xerces
                        (lambda _
                          (install-file
                            (string-append ,java-xerces  "/share/java/xercesImpl.jar")
                            "lib/xerces-latest")))
                      (add-before 'install 'remove-extra-jars
                        (lambda _
                          (delete-file "build/lib/nekohtmlSamples.jar")
                          (delete-file-recursively "lib")))
                      (replace 'install (install-from-pom "pom.xml")))))
    (home-page "https://nekohtml.sourceforge.net/")
    (synopsis "A simple HTML scanner and tag balancer that enables application programmers to parse HTML documents and
     access the information using standard XML interfaces.")
    (description
      "The parser can scan HTML files and \"fix up\" many common mistakes that human (and computer) authors make in
       writing HTML documents. NekoHTML adds missing parent elements; automatically closes elements with optional end
       tags; and can handle mismatched inline element tags. NekoHTML is written using the Xerces Native Interface (XNI)
       that is the foundation of the Xerces2 implementation. This enables you to use the NekoHTML parser with existing
       XNI tools without modification or rewriting code.")
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

(define maven-sonatype-polyglot-common
  (package
    (name "maven-sonatype-polyglot-common")
    ; Version here uses the day before the day of the next commit. This is because any release between those two days
    ; (bounds included) would be same, so the latest possible date of the needed release is used.
    (version "0.8-20100327")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
               ; Currently the source is only available on Software Heritage and only from forks. Originally it was
               ; hosted at https://github.com/sonatype/maven-polyglot which no longer exist, not even as an archive at
               ; Software Heritage, though there are some pages on Web Archive. Debian originally fetched the source
               ; (albeit a different revision) from https://github.com/tobrien/maven-polyglot, but that repository
               ; no longer exist either, but thankfully available at Software Heritage.
               ; Commit used here is the newest commit that has datetime lessthan-or-equal to the snapshot used in
               ; Gradle. Also existence of this commit can be verified both against Web Archive and tobrien's repository
               ; on Software Heritage (on branch refs/heads/master).
               (url "https://example.org")
               (commit "64de179becc3ed324daab72f7238df1404723672"))) ; Please update the comment above when you change the commit
;        (file-name (git-file-name name version)) ; TODO
        (file-name "swh_1_rev_64de179becc3ed324daab72f7238df1404723672-64de179")
        (sha256 (base32 "1lji0pjgcf16yqk6fj5r9n20q6872wr82rbzh0d22hdfrdfp1z9n"))
        (patches (list "patches/maven-sonatype-polyglot-0.8-update-maven.patch"
                   "patches/maven-sonatype-polyglot-0.8-package-version.patch"
                   "patches/maven-sonatype-polyglot-0.8-provided-groovy-dependency.patch"))
        (modules '((guix build utils)))
        (snippet `(substitute* (find-files "." ".*pom\\.xml$")
            (("\\$\\{GUIX_PACKAGE_VERSION\\}") ,version)))
        ))
    ; TODO: Prevent propagating slf4j dependencies and make these propagated-inputs
    (native-inputs (list maven-embedder maven-3.0-model-builder))
    (propagated-inputs (list maven-sonatype-polyglot-parent-pom))
    (build-system ant-build-system)
    (arguments
      `(#:jar-name "lib.jar"
         #:source-dir "pmaven-common/src/main"
         #:test-dir  "pmaven-common/src/test"
         #:tests? #f ; TODO: compile tests with groovyc
         #:phases ,#~(modify-phases %standard-phases
                       (replace 'install
                         (install-from-pom "pmaven-common/pom.xml")))))
    (home-page "https://web.archive.org/web/20100706134238/http://polyglot.sonatype.org/")
    (synopsis "Support alternative markup for Apache Maven POM files. Please note, this is an obsolete version of Polyglot.")
    (description "A library allowing to write Maven POMs in JVM and DSL languages.
    WARNING: This version of Polyglot no longer exists, not even as a Git repository. Please consider using Takari's
    Polyglot for Maven for new projects or packages instead.")
    (license license:asl2.0)))

(define maven-sonatype-polyglot-parent-pom
  (hidden-package
    (package
      (inherit maven-sonatype-polyglot-common)
      (inputs '())
      (native-inputs '())
      (propagated-inputs '())
      (build-system ant-build-system)
      (arguments
        `(#:tests? #f
           #:phases
           (modify-phases %standard-phases
             (delete 'configure)
             (delete 'build)
             (replace 'install
               (install-pom-file "pom.xml"))))))))

(define maven-sonatype-polyglot-groovy
  (package
    (inherit maven-sonatype-polyglot-common)
    (native-inputs (list groovy-ant-patched groovy
                         maven-embedder maven-3.0-model-builder)) ; TODO: remove this once propagated-inputs of the polyglot-common is fixed
    (propagated-inputs (list maven-sonatype-polyglot-parent-pom maven-sonatype-polyglot-common))
    (arguments
      `(#:jar-name "lib.jar"
         #:jdk ,openjdk9 ; same as groovy
         #:source-dir "pmaven-groovy/src/main"
         #:test-dir  "pmaven-groovy/src/test"
         #:tests? #f ; TODO
         #:phases ,#~(modify-phases %standard-phases
                       (add-before 'build 'patch-build.xml
                         (lambda _
                           (substitute* "build.xml"
                             (("<javac ([^>]+)>" all args) (string-append
                                                             "<taskdef name=\"groovyc\" classname=\"org.codehaus.groovy.ant.Groovyc\" classpathref=\"classpath\"/>"
                                                             "<groovyc " args " fork=\"true\"><classpath refid=\"classpath\"/>"
                                                             "<javac debug=\"true\" " args ">"))
                             (("</javac>" all) (string-append all "</groovyc>")))))
                       (replace 'install
                         (install-from-pom "pmaven-groovy/pom.xml")))))
    (synopsis "Support alternative markup for Apache Maven POM files. This package provides Groovy DSL. Please check the package description before using.")))

(define common-gradle-patches
  (list "patches/gradle-4.5.1-asm.patch" "patches/gradle-4.5.1-commons.patch"
     "patches/gradle-4.5.1-groovy-2.4.patch" "patches/gradle-4.5.1-groovy-2.5-1.patch" ; TODO: replace these sets having redundant patches with just diffs, and then compare with originals
     "patches/gradle-4.5.1-groovy-2.5-2.patch" "patches/gradle-4.5.1-groovy-2.5-3.patch"
     "patches/gradle-4.5.1-groovy-2.5-4.patch" "patches/gradle-4.5.1-groovy-3.patch"
     "patches/gradle-4.5.1-guava.patch" "patches/gradle-4.5.1-kryo.patch"
     "patches/gradle-4.5.1-type-inference-fix.patch" "patches/gradle-4.5.1-type-fix.patch"))
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
        (patches `(,@common-gradle-patches
                    "patches/gradle-bootstrap-4.5.1-remove-dependencies.patch"
                    "patches/gradle-bootstrap-4.5.1-single-jar.patch"
                    "patches/gradle-4.5.1-workaround-dependency-issue.patch"))
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
            java-kryo-2 java-native-platform-0.14 java-slf4j-api java-testng maven-3.0-settings-builder))
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
                                                  (close targetPort))
                                                  #t)
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

; TODO: document patches/changes in Gradle docs?
; TODO: disable patching dependencies and libs in out are bit-for-bit same as are provided by Guix
(define gradle
  (package
    (inherit gradle-bootstrap)
    (source (origin
              (inherit (package-source gradle-bootstrap))
              (patches `(,@common-gradle-patches
                         "patches/gradle-4.5.1-default-methods.patch"
                         "patches/gradle-4.5.1-dekotlinize-build-files.patch"
                         "patches/gradle-4.5.1-disable-minifying.patch" ; so that Guix link optimization works
                         "patches/gradle-4.5.1-jcifs-new-coordinates.patch" "patches/gradle-4.5.1-guix-dependencies.patch"
                         "patches/gradle-4.5.1-local-repository.patch" "patches/gradle-4.5.1-maven-dependencies.patch"
                         "patches/gradle-4.5.1-no-remote-cache.patch"
                         "patches/gradle-4.5.1-remove-complex-dependencies.patch"
                         "patches/gradle-4.5.1-remove-kotlin-dsl.patch"
                         "patches/gradle-4.5.1-reproducible-artifacts.patch"
                         "patches/gradle-4.5.1-symlink-during-install.patch"
                         "patches/gradle-4.5.1-unshaded-groovy.patch"))))
    (native-inputs (list
                     apache-commons-parent-pom-42 groovy-spock-junit4 java-commons-cli
                     java-commons-codec java-jsoup java-jcl-over-slf4j java-log4j-over-slf4j java-jcifs
                     java-hamcrest-library java-nekohtml
                     java-pegdown zip java-plexus-cipher-1.7 java-plexus-container-default-1.7
                     java-plexus-component-annotations-1.7 java-sonatype-oss-parent-pom-5 java-simple-web-4
                     java-sonatype-aether-api-1.13 java-sonatype-aether-impl-1.13 java-sonatype-aether-util-1.13
                     maven-sonatype-polyglot-common maven-sonatype-polyglot-groovy
                     maven-3.0-compat maven-3.0-core maven-parent-pom-34 maven-3.0-plugin-api maven-wagon-provider-api))
    (arguments
      `(#:modules ((guix build ant-build-system) (guix build java-utils) (guix build utils) (ice-9 ftw) (srfi srfi-1)
                    (ice-9 string-fun) (srfi srfi-26))
         ,@(substitute-keyword-arguments (package-arguments gradle-bootstrap)
             ((#:phases phases) ; TODO: verify gradle and gradle-wrapper hashes against well-known ones
               `(modify-phases %standard-phases
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
                  (add-before 'build 'patch-for-newer-maven
                    (lambda _
                      (substitute* (find-files "." ".*\\.(java|groovy)$")
                        (("org\\.eclipse\\.aether\\.(RepositorySystemSession)" _ name) 
                          (string-append "org.sonatype.aether." name)))))
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
                          "buildSrc/src/main/groovy/org/gradle/testing/PerformanceTest.java" ; depends on previous versions of Gradle
                          "subprojects/ide/src/main/java/org/gradle/plugins/ide/idea/internal/IdeaScalaConfigurer.java" ; depends on Scala

                          ; Depend on dd-plist library and only required for a properietary IDE:
                          "subprojects/ide-native/src/main/java/org/gradle/api/internal/PropertyListTransformer.java"
                          "subprojects/ide-native/src/main/java/org/gradle/plugins/ide/api/PropertyListGeneratorTask.java"
                          "subprojects/ide-native/src/main/java/org/gradle/plugins/ide/internal/generator/PropertyListPersistableConfigurationObject.java"
                          ))
                      (delete-file-recursively "buildSrc/src/main/groovy/org/gradle/binarycompatibility") ; dependends on previous versions of Gradle
                      (delete-file-recursively "buildSrc/src/test/groovy/org/gradle/binarycompatibility") ; dependends on previous versions of Gradle
                      (delete-file-recursively "buildSrc/src/main/groovy/org/gradle/testing/performance") ; dependends on previous versions of Gradle
                      (delete-file-recursively "buildSrc/src/test/groovy/org/gradle/testing/performance") ; dependends on previous versions of Gradle

                      ; Depend on dd-plist library and only required for a properietary IDE:
                      (delete-file-recursively "subprojects/ide-native/src/main/java/org/gradle/ide/xcode")
                      (delete-file-recursively "subprojects/ide-native/src/test/groovy/org/gradle/ide/xcode")

                      (substitute* (find-files "." "\\.gradle$")
                        ((" crossVersionTest[A-Za-z]+ " all) (string-append "// " all)) ; dependencies for tests depending on previous versions of Gradle
                        )))
                  (add-before 'build 'generate-groovy-pom
                    (generate-pom.xml "groovy-pom.xml" "org.codehaus.groovy" "groovy" ,(package-version groovy)))
                  (add-before 'build 'patch-versions
                    (lambda _ ; TODO: implement it in init.gradle instead
                      (substitute* "gradle/dependencies.gradle"
                        (("(com.google.guava:)guava-jdk5:([0-9][0-9.]+)([:'@\"])" _ prefix version suffix)
                          (string-append prefix "guava:[" version ",)" suffix))
                        (((string-append "((org.ow2.asm:asm[^'\":]+"
                           "|com.google.code.findbugs:jsr305"
                           "|org.apache.maven.wagon:wagon-[^'\":]+"
                           "|org.apache.xbean:xbean-[^'\":]+"
                           "|org.objenesis:objenesis"
                           "):)([0-9]+[0-9.]*)([:'@\"])") _ prefix _ version suffix)
                          (string-append prefix "[" version ",)" suffix))
                        (("net.jcip:jcip-annotations:([0-9][0-9.]+)([:'@\"])" _ _ suffix)
                          (string-append "com.google.code.findbugs:jsr305:[3,)" suffix))
                        (("(org.fusesource.jansi:jansi:)([0-9][0-9.]+)([:'@\"])" _ prefix _ suffix)
                          (string-append prefix "[1.16,2)" suffix))
                        (("([:'\"])([0-9]+)([0-9Ma-z.-]*)([:'@\"])" _ prefix major-version rest-version suffix)
                          (string-append prefix "["
                            major-version rest-version ", "
                            (number->string (1+ (string->number major-version))) ")"
                            suffix)))

                      (substitute* '("buildSrc/build.gradle"
                                      "subprojects/docs/docs.gradle"
                                      "subprojects/docs/src/transforms/release-notes.gradle"
                                      "subprojects/javascript/javascript.gradle"
                                      "subprojects/maven/maven.gradle"
                                      "subprojects/reporting/reporting.gradle")
                        (("(com.google.guava:)guava-jdk5:([0-9][0-9.]+)([:'@\"])" _ prefix version suffix)
                          (string-append prefix "guava:[" version ",)" suffix))
                        (((string-append "((org.ow2.asm:asm[^'\":]+"
                            "|com.google.code.findbugs:jsr305"
                            "|org.objenesis:objenesis"
                            "):)([0-9]+[0-9.]*)([:'@\"])") _ prefix _ version suffix)
                          (string-append prefix "[" version ",)" suffix))
                        (("net.jcip:jcip-annotations:([0-9][0-9.]+)([:'@\"])" _ _ suffix)
                          (string-append "com.google.code.findbugs:jsr305:[3,)" suffix))
                        (("(:)([0-9]+)([0-9.MRa-z-]*)([:'@\"])" _ prefix major-version rest-version suffix)
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
                              (roots (map cdr inputs))
                              (m2-packages (filter
                                             (lambda (input)
                                               (file-exists? (string-append input "/lib/m2")))
                                             roots))
                              (m2-roots (map
                                          (lambda (input) (string-append input "/lib/m2"))
                                          m2-packages)))
                        (mkdir-p (string-append dir "/.m2/repository"))
                        (for-each
                          (lambda (m2-root)
                            (with-directory-excursion m2-root
                              (for-each
                                (lambda (path-with-dot)
                                  (let* ((path-relative-to-m2-root (substring path-with-dot 2))
                                         (link-itself (string-append dir "/.m2/repository/" path-relative-to-m2-root)))
                                    (mkdir-p (dirname link-itself))
                                    (symlink
                                      (string-append m2-root "/" path-relative-to-m2-root)
                                      link-itself)))
                                (find-files "." ".+"))))
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
                                ; TODO: replace the fixed jars in outputs back to unfixed onesd to allow link optimization
                                (fix-grafted-jar (lambda (out-jar)
                                  (let* ((unzip-command (string-append ,unzip "/bin/unzip"))
                                          (zip-command (string-append ,zip "/bin/zip")))
                                    (with-directory-excursion (mkdtemp "jar-contents.XXXXXX")
                                      ; This command is expected to return a non-zero code but still extract all files
                                      (system* unzip-command out-jar)
                                      (delete-file out-jar)
                                      (let* ((files (find-files "." ".*" #:directories? #t))
                                              (command `(,zip-command "-0" "-X" ,out-jar ,@files)))
                                        (apply invoke command))))))

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
                                (asmUtilMavenPath
                                  (mavenize-package ,java-asm-util-9 ,(package-version java-asm-util-9)
                                    "org.ow2.asm" "asm-util" "/share/java/asm-util8.jar"))

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

                          ; TODO: fix the packages instead?
                          (mavenize-package ,ant ,(package-version ant)
                            "org.apache.ant" "ant" "/lib/ant.jar")
                          (mavenize-package ,ant ,(package-version ant)
                            "org.apache.ant" "ant-launcher" "/lib/ant-launcher.jar")
                          (for-each
                            (lambda (suffix)
                              (mavenize-package ,groovy ,(package-version groovy)
                                "org.codehaus.groovy"
                                (string-append "groovy-" suffix) (string-append "/lib/groovy-" suffix ".jar")))
                            (list "ant" "datetime" "dateutil" "groovydoc" "json" "templates" "xml"))
                          (mavenize-package ,groovy-test ,(package-version groovy-test)
                            "org.codehaus.groovy" "groovy-test" "/share/java/groovy-test.jar")
                          (mavenize-package ,java-cglib ,(package-version java-cglib)
                            "cglib" "cglib"
                            "/share/java/cglib.jar")
                          (mavenize-package ,java-commons-collections ,(package-version java-commons-collections)
                            "commons-collections" "commons-collections"
                            (string-append "/share/java/commons-collections-" ,(package-version java-commons-collections) ".jar"))
                          (mavenize-package ,java-commons-lang ,(package-version java-commons-lang)
                            "commons-lang" "commons-lang"
                            (string-append "/share/java/commons-lang-" ,(package-version java-commons-lang) ".jar"))
                          (mavenize-package ,java-aqute-bndlib ,(package-version java-aqute-bndlib)
                            "biz.aQute.bnd" "biz.aQute.bndlib" "/share/java/java-bndlib.jar")
                          (mavenize-package ,java-aqute-libg ,(package-version java-aqute-libg)
                            "biz.aQute.bnd" "biz.aQute.bndlib.libg" "/share/java/java-aqute-libg.jar")
                          (mavenize-package ,java-kryo-2 ,(package-version java-kryo-2)
                            "com.esotericsoftware.kryo" "kryo" "/share/java/kryo.jar")
                          (mavenize-package ,java-gson ,(package-version java-gson)
                            "com.google.code.gson" "gson" "/share/java/gson.jar")
                          (mavenize-package ,java-fasterxml-jackson-annotations ,(package-version java-fasterxml-jackson-annotations)
                            "com.fasterxml.jackson.core" "jackson-annotations" "/share/java/jackson-annotations.jar")
                          (mavenize-package ,java-fasterxml-jackson-core ,(package-version java-fasterxml-jackson-core)
                            "com.fasterxml.jackson.core" "jackson-core" "/share/java/jackson-core.jar")
                          (mavenize-package ,java-fasterxml-jackson-databind ,(package-version java-fasterxml-jackson-databind)
                            "com.fasterxml.jackson.core" "jackson-databind" "/share/java/jackson-databind.jar")
                          (mavenize-package ,java-jsch ,(package-version java-jsch)
                            "com.jcraft" "jsch" (string-append "/share/java/jsch-" ,(package-version java-jsch) ".jar"))
                          (mavenize-package ,java-jhighlight ,(package-version java-jhighlight)
                            "com.uwyn" "jhighlight" "/share/java/jhighlight.jar")
                          (mavenize-package ,java-joda-time ,(package-version java-joda-time)
                            "joda-time" "joda-time" "/share/java/java-joda-time.jar")
                          (mavenize-package ,java-native-platform-0.14 ,(package-version java-native-platform-0.14)
                            "net.rubygrapefruit" "native-platform" "/share/java/native-platform.jar")
                          (mavenize-package ,java-httpcomponents-httpclient ,(package-version java-httpcomponents-httpclient)
                            "org.apache.httpcomponents" "httpclient" "/share/java/httpcomponents-httpclient.jar")
                          (mavenize-package ,java-httpcomponents-httpcore ,(package-version java-httpcomponents-httpcore)
                            "org.apache.httpcomponents" "httpcore" "/share/java/httpcomponents-httpcore.jar")

                          (fix-grafted-jar (mavenize-package ,java-apache-ivy ,(package-version java-apache-ivy)
                                     "org.apache.ivy" "ivy" "/share/java/ivy.jar"))

                          (mavenize-package ,maven-resolver-transport-wagon ,(package-version maven-resolver-transport-wagon)
                            "org.apache.maven.resolver" "maven-resolver-transport-wagon" "/share/java/maven-resolver-transport-wagon.jar")
                          (mavenize-package ,maven-wagon-file ,(package-version maven-wagon-file)
                            "org.apache.maven.wagon" "wagon-file" "/share/java/maven-wagon-file.jar")
                          (mavenize-package ,maven-wagon-http ,(package-version maven-wagon-http)
                            "org.apache.maven.wagon" "wagon-http" "/share/java/maven-wagon-http.jar")
                          (mavenize-package ,maven-wagon-http-shared ,(package-version maven-wagon-http-shared)
                            "org.apache.maven.wagon" "wagon-http-shared" "/share/java/maven-wagon-http-shared.jar")

                          (for-each
                            (lambda (prefix)
                              (mavenize-package ,java-bouncycastle ,(package-version java-bouncycastle)
                                "org.bouncycastle" prefix
                                (string-append "/share/java/" prefix "-"
                                  (string-concatenate (string-split ,(package-version java-bouncycastle) #\.)) ".jar")))
                            (list "bcpg-jdk15on" "bcprov-jdk15on"))

                          (mavenize-package ,java-jgit ,(package-version java-jgit)
                            "org.eclipse.jgit" "org.eclipse.jgit" "/share/java/jgit.jar")

                          (mavenize-package ,java-jmock ,(package-version java-jmock)
                            "org.jmock" "jmock" "/share/java/java-jmock.jar")
                          (mavenize-package ,java-jmock-junit4 ,(package-version java-jmock-junit4)
                            "org.jmock" "jmock-junit4" "/share/java/java-jmock-junit4.jar")
                          (mavenize-package ,java-jmock-legacy ,(package-version java-jmock-legacy)
                            "org.jmock" "jmock-legacy" "/share/java/java-jmock-legacy.jar")

                          (mavenize-package ,java-jsoup ,(package-version java-jsoup)
                            "org.jsoup" "jsoup" "/share/java/jsoup.jar")

                          (fix-grafted-jar (mavenize-package ,rhino ,(package-version rhino)
                            "org.mozilla" "rhino" "/share/java/js.jar"))
                          (mavenize-package ,java-objenesis ,(package-version java-objenesis)
                            "org.objenesis" "objenesis" "/share/java/objenesis.jar")
                          (mavenize-package ,java-testng ,(package-version java-testng)
                            "org.testng" "testng" "/share/java/java-testng.jar")
                          (mavenize-package ,java-jaxp ,(package-version java-jaxp)
                            "xml-apis" "xml-apis" "/share/java/jaxp.jar")
                          (mavenize-package ,java-xerces ,(package-version java-xerces)
                            "xerces" "xercesImpl" "/share/java/xercesImpl.jar")

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
                            ; TODO: set number of worker threads based on '--cores' Guix argument
                            "--info"
;                            "--stacktrace"
                            "test"
                            ; TODO "integTest"
                            "install"
                            "-PbuildTimestamp=19700101000000+0000"
                            (string-append "-Pgradle_installPath=" (assoc-ref outputs "out")))))

                      ;; copied from strip-jar-timestamps where it was copied from (gnu build install)
                      (for-each (lambda (file)
                                  (let ((s (lstat file)))
                                    (unless (eq? (stat:type s) 'symlink)
                                      (utime file 0 0 0 0))))
                        (find-files (assoc-ref outputs "out") #:directories? #t))))
                  (delete 'install)
                  (delete 'generate-jar-indices)
                  (delete 'reorder-jar-content)
                  (delete 'strip-jar-timestamps))))))))

gradle
