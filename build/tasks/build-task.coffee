fs = require 'fs'
path = require 'path'
_ = require 'underscore-plus'

module.exports = (grunt) ->
  {cp, isAtomPackage, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'build', 'Build the application', ->
    shellAppDir = grunt.config.get('atom.shellAppDir')
    buildDir = grunt.config.get('atom.buildDir')
    appDir = grunt.config.get('atom.appDir')

    rm shellAppDir
    mkdir path.dirname(buildDir)

    if process.platform is 'darwin'
      cp 'atom-shell/Atom.app', shellAppDir
    else
      cp 'atom-shell', shellAppDir

    mkdir appDir

    cp 'atom.sh', path.join(appDir, 'atom.sh')
    cp 'package.json', path.join(appDir, 'package.json')

    packageDirectories = []
    nonPackageDirectories = [
      'benchmark'
      'dot-atom'
      'vendor'
      'resources'
    ]

    {devDependencies} = grunt.file.readJSON('package.json')
    for child in fs.readdirSync('node_modules')
      directory = path.join('node_modules', child)
      if isAtomPackage(directory)
        packageDirectories.push(directory)
      else
        nonPackageDirectories.push(directory)

    # Put any paths here that shouldn't end up in the built Atom.app
    # so that it doesn't becomes larger than it needs to be.
    ignoredPaths = [
      path.join('git-utils', 'deps')
      path.join('oniguruma', 'deps')
      path.join('less', 'dist')
      path.join('less', 'test')
      path.join('bootstrap', 'docs')
      path.join('bootstrap', 'examples')
      path.join('pegjs', 'examples')
      path.join('plist', 'tests')
      path.join('xmldom', 'test')
      path.join('combined-stream', 'test')
      path.join('delayed-stream', 'test')
      path.join('domhandler', 'test')
      path.join('fstream-ignore', 'test')
      path.join('harmony-collections', 'test')
      path.join('lru-cache', 'test')
      path.join('minimatch', 'test')
      path.join('normalize-package-data', 'test')
      path.join('npm', 'test')
      path.join('jasmine-reporters', 'ext')
      path.join('jasmine-node', 'node_modules', 'gaze')
      path.join('build', 'Release', 'obj.target')
      path.join('build', 'Release', 'obj')
      path.join('build', 'Release', '.deps')
      path.join('vendor', 'apm')
      path.join('resources', 'mac')
      path.join('resources', 'win')
    ]
    ignoredPaths = ignoredPaths.map (ignoredPath) -> _.escapeRegExp(ignoredPath)

    # Add .* to avoid matching hunspell_dictionaries.
    ignoredPaths.push "#{_.escapeRegExp(path.join('spellchecker', 'vendor', 'hunspell') + path.sep)}.*"
    ignoredPaths.push "#{_.escapeRegExp(path.join('build', 'Release') + path.sep)}.*\\.pdb"

    # Hunspell dictionaries are only not needed on OS X.
    if process.platform is 'darwin'
      ignoredPaths.push path.join('spellchecker', 'vendor', 'hunspell_dictionaries')
    ignoredPaths = ignoredPaths.map (ignoredPath) -> "(#{ignoredPath})"
    nodeModulesFilter = new RegExp(ignoredPaths.join('|'))
    packageFilter = new RegExp("(#{ignoredPaths.join('|')})|(.+\\.(cson|coffee)$)")
    for directory in nonPackageDirectories
      cp directory, path.join(appDir, directory), filter: nodeModulesFilter
    for directory in packageDirectories
      cp directory, path.join(appDir, directory), filter: packageFilter

    cp 'spec', path.join(appDir, 'spec')
    cp 'src', path.join(appDir, 'src'), filter: /.+\.(cson|coffee)$/
    cp 'static', path.join(appDir, 'static')
    cp 'apm', path.join(appDir, 'apm'), filter: nodeModulesFilter

    if process.platform is 'darwin'
      grunt.file.recurse path.join('resources', 'mac'), (sourcePath, rootDirectory, subDirectory='', filename) ->
        unless /.+\.plist/.test(sourcePath)
          grunt.file.copy(sourcePath, path.resolve(appDir, '..', subDirectory, filename))

    if process.platform is 'win32'
      cp path.join('resources', 'win', 'msvcp100.dll'), path.join(shellAppDir, 'msvcp100.dll')
      cp path.join('resources', 'win', 'msvcr100.dll'), path.join(shellAppDir, 'msvcr100.dll')

      # Set up chocolatey ignore and gui files
      fs.writeFileSync path.join(appDir, 'apm', 'node_modules', 'atom-package-manager', 'bin', 'node.exe.ignore'), ''
      fs.writeFileSync path.join(appDir, 'node_modules', 'symbols-view', 'vendor', 'ctags-win32.exe.ignore'), ''
      fs.writeFileSync path.join(shellAppDir, 'atom.exe.gui'), ''

    dependencies = ['compile', "generate-license:save"]
    dependencies.push('copy-info-plist') if process.platform is 'darwin'
    dependencies.push('set-exe-icon') if process.platform is 'win32'
    grunt.task.run(dependencies...)
