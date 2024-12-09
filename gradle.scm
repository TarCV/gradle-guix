;;;    Copyright 2024 TarCV
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
  #:use-module (gnu packages compression)
  #:use-module (gnu packages groovy)
  #:use-module (gnu packages java)
  #:use-module (guix build utils)
  #:use-module (guix build-system ant)
  #:use-module (srfi srfi-1)
)


(define (gradle-source-by-tag version sha256sum additional-patches)
  (origin
    (method url-fetch) ;url-fetch instead of git-fetch to avoid spending too much inodes on all kotlin versions
    (uri (string-append
          "https://github.com/JetBrains/kotlin/archive/refs/tags/build-"
          version ".tar.gz"))
    (file-name (string-append "gradle-" version ".tar.gz"))
    (sha256 (base32 sha256sum))
    (patches `(,(string-append "patches/kotlin-" version ".patch") ,@additional-patches))
    (modules '((guix build utils)))
    (snippet `(for-each delete-file
                        (find-files "." ".*\\.(a|class|exe|jar|so|zip)$")))))

(define (gradle-source-by-release version sha256sum additional-patches)
  (origin
    (method url-fetch) ;url-fetch instead of git-fetch to avoid spending too much inodes on all kotlin versions
    (uri (string-append
           "https://github.com/JetBrains/kotlin/archive/refs/tags/v"
           version ".tar.gz"))
    (file-name (string-append "gradle-" version ".tar.gz"))
    (sha256 (base32 sha256sum))
    (patches `(,@additional-patches))
    (modules '((guix build utils)))
    (snippet `(for-each delete-file
                        (find-files "." ".*\\.(a|class|exe|jar|so|zip)$")))))

(define* (package-by-inheriting-gradle-package inherited-package
                                               version
                                               sha256sum
                                               additional-patches
                                               #:key (set-native-inputs (lambda 
                                                                                (v)
                                                                          v))
                                               (set-jdk (lambda (v)
                                                          v))
                                               (set-phases (lambda (v)
                                                             v)))
  (package
    (inherit inherited-package)
    (version version)
    (source
     (gradle-source-by-tag version sha256sum additional-patches))
    (native-inputs `(,@(set-native-inputs (package-native-inputs
                                           inherited-package))))
    (arguments
     `(,@(substitute-keyword-arguments (package-arguments inherited-package)
           ((#:jdk jdk)
            (set-jdk jdk))
           ((#:make-flags make-flags)
            (kotlin-make-flags version inherited-package))
           ((#:phases phases)
            (set-phases phases)))))))

(define* (release-package-by-inheriting-gradle-package inherited-package
                                                       version
                                                       sha256sum
                                                       additional-patches
                                                       #:key (set-native-inputs (lambda 
                                                                                        (v)
                                                                                  v))
                                                       (set-jdk (lambda (v)
                                                                  v))
                                                       (set-phases (lambda (v)
                                                                     v)))
  (package
    (inherit inherited-package)
    (version version)
    (source
     (gradle-source-by-release version sha256sum additional-patches))
    (native-inputs `(,@(set-native-inputs (package-native-inputs
                                           inherited-package))))
    (arguments
     `(,@(substitute-keyword-arguments (package-arguments inherited-package)
           ((#:jdk jdk)
            (set-jdk jdk))
           ((#:make-flags make-flags)
            (kotlin-make-flags version inherited-package))
           ((#:phases phases)
            (set-phases phases)))))))

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

(define groovy-all
  (package
    (name "groovy-all")
    (version (package-version groovy))
    (source
      (origin
        (inherit (package-source groovy))))
    (native-inputs
      (list groovy unzip))
    (build-system ant-build-system)
    (arguments ; TODO: Try patching classpath in groovy.jar (or other jars?) instead of this hack
      `(#:jar-name "groovy-all.jar" ; TODO: why grafting breaks this jar?
         #:source-dir "empty-src-dir" ;; just jar existing compiled classes, no sources needed
         #:tests? #f
         #:jdk ,openjdk9
         #:phases
         ,#~(modify-phases %standard-phases
              (add-before 'build 'create-empty-src-dir
                (lambda _
                  (mkdir-p "empty-src-dir")))
              (add-before 'build 'unzip-jars
                (lambda* (#:key inputs #:allow-other-keys)
                  (mkdir-p "build/classes")
                  (for-each
                    (lambda (f)
                      (invoke (string-append #$unzip "/bin/unzip")
                        f
                        "-d"
                        "build/classes"
                        ;; These files are generated by 'jar' target for each jar file it creates
                        "-x"
                        "META-INF/INDEX.LIST"
                        "META-INF/MANIFEST.MF"))
                    (find-files
                      (assoc-ref inputs "groovy")
                      "^(groovy-|[^g]).+\\.jar$"))

                  ;; Extract the main jar last to keep its MANIFEST.MF
                  (invoke (string-append #$unzip "/bin/unzip")
                    (car (find-files
                           (assoc-ref inputs "groovy")
                           "^groovy\\.jar$"))
                    "-d"
                    "build/classes"
                    ;; These files are generated by 'jar' target for each jar file it creates
                    "-x"
                    "META-INF/INDEX.LIST")
                  (mkdir-p "build/manifest")
                  (rename-file "build/classes/META-INF/MANIFEST.MF" "build/manifest/MANIFEST.MF")))
              (add-after 'install 'copy-original-files
                (lambda* (#:key inputs #:allow-other-keys)
                  (copy-recursively (assoc-ref inputs "groovy") #$output)
                  (delete-file-recursively (string-append #$output "/lib"))))
              (add-after 'copy-original-files 'install-lib
                (lambda _
                  (substitute* (string-append #$output "/bin/startGroovy")
                    (("groovy\\.jar") "groovy-all.jar"))))
              (add-after 'copy-original-files 'install-lib
                (lambda _
                  (rename-file (string-append #$output "/share/java") (string-append #$output "/lib"))))
              (delete 'install-license-files) ; 'copy-original-files does the same
            )))
    (home-page "https://groovy-lang.org/")
    (synopsis "Groovy uberjar with every jar from Groovy package")
    (description "Groovy uberjar with every jar from Groovy package")
    (license license:asl2.0)))

(define gradle-ant-bootstrap
  (package
    (name "gradle")
    (version "0.0.0-355")
    (source
      (origin
        (method url-fetch)
        (uri (string-append "https://github.com/gradle/gradle/archive/68ed305dc9ea1efedf6e5774451dbd7a0725494e.tar.gz"))
        (file-name (string-append "gradle-" version ".tar.gz"))
        (sha256 (base32 "0fdbnxrk12s40z8i1njjkqai3zgrvpcb6x8pwcpm3x0qsj92wv01"))
        (patches '("patches/gradle-0.0.0-355-ant-no-samples.patch"
                   "patches/gradle-0.0.0-355-ant-remove-groovy-task.patch"
                   "patches/gradle-0.0.0-355-remove-groovy-task.patch"
                   "patches/gradle-0.0.0-355-default-parameters.patch" "patches/gradle-0.0.0-355-java.patch"
                   "patches/gradle-0.0.0-355-includeAntRuntime.patch"
                   "patches/gradle-0.0.0-355-ant-reproducibility.patch" "patches/gradle-0.0.0-355-reproducibility.patch"
                    ))
        (modules '((guix build utils)))
        (snippet '(begin
                    (for-each delete-file
                      (find-files "." ".*\\.(a|class|exe|jar|so|zip)$"))
                    #t))))
    (propagated-inputs
      (list apache-ivy-2.0-beta2 java-commons-cli java-commons-httpclient java-commons-io java-commons-lang java-junit
            java-logback-classic java-logback-core java-slf4j-api groovy-all))
    (build-system ant-build-system)
    (arguments
      `(#:jdk ,openjdk9 ; same as groovy
         #:make-flags (list
                        ,#~(string-append "-DdistExplodedDir=" #$output)
                        "-Dtest.skip=true"
                        "-Dintegtest.skip=true")
         #:build-target "buildExplodedDist"
         #:tests? #f ; depends on groovy test classes not present in Guix
         #:phases (modify-phases %standard-phases
                    (add-before 'build 'remove-ivy
                      (lambda _
                        (substitute* "build.xml"
                          (("<ivy:[^>]+/>") "")
                          (("depends=\"install-ivy\"") "")
                          (("(classpathref|refid)=\"[^\">]*\"") ""))))
                    (add-before 'build 'remove-cobertura
                      (lambda _
                        (substitute* "build.xml"
                          (("depends=\"instrument([,\"])" all separator)
                            (string-append "depends=\"compile" separator)))))
                    (add-before 'build 'remove-slide-webdav
                      ; Avoid dependency on WebDAV client from the retired Jakarta Slide project
                      (lambda _
                        (delete-file "src/main/groovy/org/gradle/api/internal/dependencies/WebdavRepository.java")
                        (delete-file "src/main/groovy/org/gradle/api/internal/dependencies/WebdavResolver.java")
                        ))
                    (add-before 'build 'fix-target-version
                      (lambda _
                        (substitute* "build.xml"
                          (("source=\"1.5\" target=\"1.5\"") "source=\"1.6\" target=\"1.6\""))))
                    ,#~(add-after 'build 'fix-run-scripts
                      (lambda* (#:key inputs #:allow-other-keys)
                        (substitute* (find-files (string-append #$output "/bin") "gradle.*")
                          (("CLASSPATH=" all)
                            (string-append all "$CLASSPATH:")))))
                    (delete 'install) ;already implemented in build.xml
                  )))
    (home-page "https://gradle.org/")
    (synopsis "Open-source build automation tool with an extensible declarative build language")
    (description
      "Gradle Build Tool is a fast, dependable, and adaptable open-source build automation tool with an elegant and extensible declarative build language.")
    (license license:asl2.0)))

(define gradle-bootstrap
  (package
    (inherit gradle-ant-bootstrap)
    (name "gradle")
    (source
      (origin
        (inherit (package-source gradle-ant-bootstrap))
        (patches '("patches/gradle-0.0.0-355-default-parameters.patch" "patches/gradle-0.0.0-355-java.patch"
                   "patches/gradle-0.0.0-355-remove-svn.patch" "patches/gradle-0.0.0-355-offline-script.patch"
                   "patches/gradle-0.0.0-355-includeAntRuntime.patch" "patches/gradle-0.0.0-355-reproducibility.patch"
                  ))))
    (build-system ant-build-system)
    (native-inputs (list gradle-ant-bootstrap))
    (arguments
      `(#:jdk ,openjdk9 ; same as groovy
         #:tests? #f ; depends on groovy test classes not present in Guix
         #:modules ((guix build ant-build-system) (guix build utils) (ice-9 ftw) (srfi srfi-1) (ice-9 string-fun)
                    (srfi srfi-26))
         #:phases (modify-phases %standard-phases
                    (add-before 'build 'remove-src-tests
                      (lambda _ ; remove tests as they depend on groovy test classes not present in Guix
                        (delete-file-recursively "src/test")))
                    (add-before 'build 'remove-build-src-tests
                      (lambda _ ; remove tests as they depend on groovy test classes not present in Guix
                        (delete-file-recursively "buildSrc/src/test")))
                    (add-before 'build 'create-missing-samples-dir
                      (lambda _
                        (mkdir-p "src/samples")))
                    (add-before 'build 'fix-target-version
                      (lambda _
                        (substitute* "gradlefile"
                          (("((source|target)Compatibility = )1.5" _ prefix)
                            (string-append prefix "1.6")))))
                    (add-before 'build 'remove-slide-webdav
                      ; Avoid dependency on WebDAV client from the retired Jakarta Slide project
                      (lambda _
                        (delete-file "src/main/groovy/org/gradle/api/internal/dependencies/WebdavRepository.java")
                        (delete-file "src/main/groovy/org/gradle/api/internal/dependencies/WebdavResolver.java")
                        ))
                    (add-before 'build 'remove-svn
                      (lambda _
                        (delete-file "buildSrc/src/main/groovy/org/gradle/build/release/Svn.groovy")))
                    (add-before 'build 'fix-dependencies-call
                      (lambda _
                        (substitute* "gradlefile"
                          (("dependencies\\(([^\\)]+)\\)" _ middle)
                            (string-append "[" middle "].each { dependency(it) }")))))
                    (add-before 'build 'replace-versions
                      (lambda _
                        (substitute* "gradlefile"
                          (("(org.codehaus.groovy)?(:groovy-all:)[^:'\"]+" _ _ prefix)
                            (string-append "org.codehaus.groovy" prefix ,(package-version groovy-all)))
                          (("(commons-cli)?(:commons-cli:)[^:'\"]+" _ _ prefix)
                            (string-append "commons-cli" prefix ,(package-version java-commons-cli)))
                          (("(commons-io)?(:commons-io:)[^:'\"]+" _ _ prefix)
                            (string-append "commons-io" prefix ,(package-version java-commons-io)))
                          (("(commons-lang)?(:commons-lang:)[^:'\"]+" _ _ prefix)
                            (string-append "commons-lang" prefix ,(package-version java-commons-lang)))
                          (("(commons-httpclient)?(:commons-httpclient:)[^:'\"]+" _ _ prefix)
                            (string-append "commons-httpclient" prefix ,(package-version java-commons-httpclient)))
                          (("(ch.qos.logback)?(:logback-classic:)[^:'\"]+" _ _ prefix)
                            (string-append "ch.qos.logback" prefix ,(package-version java-logback-classic)))
                          (("(ch.qos.logback)?(:logback-core:)[^:'\"]+" _ _ prefix)
                            (string-append "ch.qos.logback" prefix ,(package-version java-logback-core)))
                          (("(org.apache.ant)?(:ant-launcher:)[^:'\"]+" _ _ prefix)
                            (string-append "org.apache.ant" prefix ,(package-version ant)))
                          (("(junit)?(:junit:)[^:'\"]+" _ _ prefix)
                            (string-append "junit" prefix ,(package-version java-junit)))
                          (("(org.apache.ant)?(:ant:)[^:'\"]+" _ _ prefix)
                            (string-append "org.apache.ant" prefix ,(package-version ant)))
                          (("(org.apache.ant)?(:ant-junit:)[^'\"]+" _ _ prefix) ; intentionally missing colon here
                            (string-append "org.apache.ant" prefix ,(package-version ant-junit)))
                          (("(org.apache.ivy)?(:ivy:)[^:'\"]+" _ _ prefix)
                            (string-append "org.apache.ivy" prefix ,(package-version apache-ivy-2.0-beta2)))
                          (("(org.slf4j)?(:slf4j-api:)[^:'\"]+" _ _ prefix)
                            (string-append "org.slf4j" prefix ,(package-version java-slf4j-api)))
                          )))
                    (replace 'build
                      (lambda* (#:key inputs #:allow-other-keys)
                        (let* ((dir (string-append (getenv "TMP") "/" (mkdtemp "build-home.XXXXXX")))
                               (m2-packages (filter
                                              (lambda (input)
                                                (file-exists? (string-append (cdr input) "/lib/m2")))
                                              inputs))
                               (m2-roots (map
                                              (lambda (input) (string-append (cdr input) "/lib/m2"))
                                              m2-packages)))
                          (mkdir-p (string-append dir "/.gradle/m2"))
                          (for-each
                            (lambda (m2-root)
                              (copy-recursively
                                m2-root
                                (string-append dir "/.gradle/m2")))
                            m2-roots)

                          (let* ((group "commons-cli") (name "commons-cli") (version ,(package-version java-commons-cli))
                                (groupPath (string-replace-substring group "." "/")))
                            ; Gradle doesn't like this POM file
                            (delete-file
                              (string-append
                                dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".pom")))

                          (let* ((group "ch.qos.logback") (name "logback-classic")
                                 (version ,(package-version java-logback-classic))
                                 (groupPath (string-replace-substring group "." "/"))
                                 (path (string-append
                                        dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,java-logback-classic "/share/java/logback-classic.jar") path))

                          (let* ((group "ch.qos.logback") (name "logback-core")
                                 (version ,(package-version java-logback-core))
                                 (groupPath (string-replace-substring group "." "/"))
                                 (path
                                   (string-append
                                     dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,java-logback-core "/share/java/logback.jar") path))

                          (let* ((group "commons-lang") (name "commons-lang")
                                 (version ,(package-version java-commons-lang))
                                 (groupPath (string-replace-substring group "." "/"))
                                 (path
                                   (string-append
                                     dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink
                              (string-append ,java-commons-lang "/share/java/commons-lang-" version ".jar")
                              path))

                          (let* ((group "commons-httpclient") (name "commons-httpclient")
                                 (version ,(package-version java-commons-httpclient))
                                 (groupPath (string-replace-substring group "." "/"))
                                 (path
                                   (string-append
                                     dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink
                              (string-append ,java-commons-httpclient "/share/java/commons-httpclient.jar")
                              path))

                          (let* ((group "junit") (name "junit") (version ,(package-version ant-junit))
                                  (groupPath (string-replace-substring group "." "/"))
                                  (path
                                    (string-append
                                      dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,ant-junit "/share/java/ant-junit.jar") path))

                          (let* ((group "org.apache.ant") (name "ant") (version ,(package-version ant))
                                (groupPath (string-replace-substring group "." "/"))
                                (path
                                  (string-append
                                    dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,ant "/lib/ant.jar") path))

                          (let* ((group "org.apache.ant") (name "ant-junit") (version ,(package-version ant-junit))
                                (groupPath (string-replace-substring group "." "/"))
                                (path
                                  (string-append
                                    dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,ant-junit "/share/java/ant-junit.jar") path))

                          (let* ((group "org.apache.ant") (name "ant-launcher") (version ,(package-version ant))
                                (groupPath (string-replace-substring group "." "/"))
                                (path
                                  (string-append
                                    dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,ant "/lib/ant-launcher.jar") path))

                          (let* ((group "org.apache.ivy") (name "ivy") (version ,(package-version apache-ivy-2.0-beta2))
                                (groupPath (string-replace-substring group "." "/"))
                                (path
                                  (string-append
                                    dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,apache-ivy-2.0-beta2 "/share/java/ivy.jar") path))

                          (let* ((group "org.codehaus.groovy") (name "groovy-all") (version ,(package-version groovy-all))
                                  (groupPath (string-replace-substring group "." "/"))
                                  (path
                                    (string-append
                                      dir "/.gradle/m2/" groupPath "/" name "/" version "/" name "-" version ".jar")))
                            (mkdir-p (dirname path))
                            (symlink (string-append ,groovy-all "/lib/groovy-all.jar") path))

                          (setenv "HOME" dir)
                          (invoke
                            (string-append (assoc-ref inputs "gradle") "/bin/gradle")
                            "--depInfo" "--stacktrace"
                            "--prop" (string-append "user.home=" dir)
                            "--gradleUserHome" (string-append dir "/.gradle")
                            "explodedDist"))))
                    (replace 'install
                      ,#~(lambda* (#:key outputs #:allow-other-keys)
                           (copy-recursively "build/distributions/exploded" #$output)))
                    (delete 'reorder-jar-content)
                    (delete 'generate-jar-indices)
                    (delete 'strip-jar-timestamps))))))

(define gradle-bootstrap-2
  (package
    (inherit gradle-bootstrap)
    (native-inputs (list gradle-bootstrap))))

;gradle-ant-bootstrap
;gradle-bootstrap
gradle-bootstrap-2
