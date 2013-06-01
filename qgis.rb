require 'formula'

class PyQtImportable < Requirement
  fatal true
  satisfy { quiet_system 'python', '-c', 'from PyQt4 import QtCore' }

  def message
    <<-EOS.undent
      Python could not import the PyQt4 module. This will cause the QGIS build to fail.
      The most common reason for this failure is that the PYTHONPATH needs to be adjusted.
      The pyqt caveats explain this adjustment and may be reviewed using:

          brew info pyqt
    EOS
  end
end

class Qgis < Formula
  homepage 'http://www.qgis.org'
  url 'http://qgis.org/downloads/qgis-1.8.0.tar.bz2'
  sha1 '99c0d716acbe0dd70ad0774242d01e9251c5a130'

  head 'https://github.com/qgis/Quantum-GIS.git', :branch => 'master'

  depends_on 'cmake' => :build
  depends_on PyQtImportable

  depends_on 'gsl'
  depends_on 'pyqt'
  depends_on 'qwt'
  depends_on 'expat'
  depends_on 'gdal'
  depends_on 'proj'
  depends_on 'spatialindex'
  depends_on 'bison'
  depends_on 'grass' => :optional
  depends_on 'gettext' if build.with? 'grass'
  depends_on 'postgis' => :optional

  def install
    # Set bundling level back to 0 (the default in all versions prior to 1.8.0)
    # so that no time and energy is wasted copying the Qt frameworks into QGIS.
    args = std_cmake_args.concat %W[
      -DQWT_INCLUDE_DIR=#{Formula.factory('qwt').opt_prefix}/lib/qwt.framework/Headers/
      -DQWT_LIBRARY=#{Formula.factory('qwt').opt_prefix}/lib/qwt.framework/qwt
      -DBISON_EXECUTABLE=#{Formula.factory('bison').opt_prefix}/bin/bison
      -DENABLE_TESTS=NO
      -DQGIS_MACAPP_BUNDLE=0
      -DQGIS_MACAPP_DEV_PREFIX='#{prefix}/Frameworks'
      -DQGIS_MACAPP_INSTALL_DEV=YES
    ]

    # todo: set the python executable

    args << "-DGRASS_PREFIX='#{Formula.factory('grass').opt_prefix + Formula.factory('grass').installed_version}'" if build.with? 'grass'

    # So that `libintl.h` can be found
    ENV.append 'CXXFLAGS', "-I'#{Formula.factory('gettext').opt_prefix}/include'" if build.with? 'grass'

    # Avoid ld: framework not found QtSql (https://github.com/Homebrew/homebrew-science/issues/23)
    ENV.append 'CXXFLAGS', "-F#{Formula.factory('qt').opt_prefix}/lib -F#{Formula.factory('python').opt_prefix}/Frameworks"

    Dir.mkdir 'build'
    Dir.chdir 'build' do
      system 'cmake', '..', *args
      system 'make install'
    end

    # Symlink the qgis Python module somewhere convienant for users to put on
    # their PYTHONPATH
    py_lib = lib/"#{which_python}/site-packages"
    qgis_modules = prefix + 'QGIS.app/Contents/Resources/python/qgis'
    py_lib.mkpath
    ln_s qgis_modules, py_lib + 'qgis'

    # Create script to launch QGIS app
    (bin + 'qgis').write <<-EOS.undent
      #!/bin/sh
      # Ensure Python modules can be found when QGIS is running.
      env PATH='#{HOMEBREW_PREFIX}/bin':$PATH PYTHONPATH='#{HOMEBREW_PREFIX}/lib/#{which_python}/site-packages':$PYTHONPATH\\
        open #{prefix}/QGIS.app
    EOS
  end

  def which_python
    "python"+`python -c 'import sys;print(sys.version[:3])'`.chomp
  end

  def caveats; <<-EOS.undent
    QGIS has been built as an application bundle. To make it easily available, a
    wrapper script has been written that launches the app with environment
    variables set so that Python modules will be functional:

      qgis

    You may also symlink QGIS.app into ~/Applications:
      brew linkapps
      mkdir -p #{ENV['HOME']}/.MacOSX
      defaults write #{ENV['HOME']}/.MacOSX/environment.plist PYTHONPATH -string "#{HOMEBREW_PREFIX}/lib/#{which_python}/site-packages"

    You will need to log out and log in again to make environment.plist effective.

    The QGIS python modules have been symlinked to:

      #{HOMEBREW_PREFIX}/lib/#{which_python}/site-packages

    If you are interested in PyQGIS development and are not using the Homebrew
    Python formula, then you will need to ensure this directory is on your
    PYTHONPATH.
    EOS
  end
end
