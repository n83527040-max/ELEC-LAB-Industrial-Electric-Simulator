@echo off
set DIR=%~dp0
if defined JAVA_HOME (set JAVA=%JAVA_HOME%\bin\java.exe) else (set JAVA=java.exe)
"%JAVA%" -Xmx64m -Xms64m -classpath "%DIR%\gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
