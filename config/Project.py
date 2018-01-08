# SCons tool set-arch.py
import os
import ProjectMacro

import SCons.Tool.MSCommon.vc

def generate(env, **kw):
    Arch = ProjectMacro.getArch()

    #env['ENV']['SCONS_BUILD'] = '1'

    if Arch in ['x86Linux','cygwin']:
        if not 'gcc_version' in env:
#            env['gcc_version'] = '4.6.3'
            env['gcc_version'] = subprocess.check_output(['gcc', '-dumpversion'])[:3]
        #env['debug_flags'] = '-g'
        env['debug_flags'] = '-gdwarf-3'
        env['opt_flags'] = '-O'
        env['ENV']['PATH'] = '/bin:/usr/bin'
        env['ENV']['LD_LIBRARY_PATH'] = ''

        if 'CLANG' in os.environ: # set by scan-build
            env['ENV'].update(x for x in os.environ.items() if (x[0].startswith('CCC_') or x[0].startswith('CLANG')))
            env['use_clangsa'] = True
        if 'use_clangsa' in env and env['use_clangsa']:
            env['CC']     = os.environ.get('CC')
            env['CXX']    = os.environ.get('CXX')
        elif 'use_clang' in env and env['use_clang']:
            env['CC']     = "clang"
            env['CXX']    = "clang++"
        else:
            if os.path.exists("/usr/bin/gcc-" + env['gcc_version']):
                env['CC'] = 'gcc-' + env['gcc_version']
            else:
                env['CC'] = 'gcc'
            if os.path.exists("/usr/bin/g++-" + env['gcc_version']):
                env['CXX'] = 'g++-' + env['gcc_version']
            else:
                env['CXX'] = 'g++'

        env['CXXVERSION'] = env['gcc_version']

        if Arch=='x86Linux':
            env['Suffix64']='64'
            env['output_folder'] = 'opt64'
            env['java_arch'] = 'amd64'
        else:
            env['Suffix64']=''
            env['output_folder'] = 'opt'
            env['java_arch'] = ''

    elif Arch in ['x86sol','sun4sol']:
        env['debug_flags'] = '-g0'
        env['opt_flags'] = '-fast'
        if Arch=='x86sol':
            env['cc_path'] = '/sunpro/sun-studio-12.x86sol_2/SUNWspro/bin'
        else:
            env['cc_path'] = '/sunpro/sun-studio-12/SUNWspro/bin'
        #/opt/SUNWspro/bin:/usr/sfw/bin
        env['ENV']['PATH'] = env['cc_path'] + ':/usr/bin:/usr/sbin:/usr/ccs/bin:/usr/local/bin'
        env['ENV']['LD_LIBRARY_PATH'] = ''
        env['CC'] = 'cc'
        env['CXX'] = 'CC'
        env['Suffix64']=''
        env['output_folder'] = 'opt'
        if Arch=='x86sol':
            env['java_arch'] = 'i386'
        else:
            env['java_arch'] = 'sparc'
    print "CC is:", env['CC']
    print "CXX is:", env['CXX']

    if Arch == 'x86Linux':
        env['CCFLAGS'] = [
            '-pthread',
            '-g',
            #'-Werror',
            '-Wall',
            '-fdiagnostics-show-option', #sonar cxx
            '-Wl,-z,relro',
            '-Wformat',
            '-Wformat-security',
            '-Wno-unused-parameter',
            '-Wextra',
            '-Wpedantic',
            #'-Wunreacheable-code',
            '-ansi',
            '-O3',
            '-m64',
            '-fomit-frame-pointer',
            #'-fno-rtti',
            '-fexceptions',
            #'-Wno-deprecated',
            #'-Wno-ctor-dtor-privacy',
            '-Dlinux',
            '-DNDEBUG', #assert
            '-pedantic',
            '-pedantic-errors',
            #'-fstrict-aliasing',
            '-DACE_HAS_EXCEPTIONS',
            '-DuseTao',
            '-fPIC',
            #'-D_TEMPLATES_ENABLE_',
            #'-include','/usr/include/stdio.h',
            #'-include','/usr/include/stdlib.h',
            #'-include','/usr/include/c++/' + env['gcc_version'] + '/cstring',
            #'-include','/usr/include/c++/' + env['gcc_version'] + '/typeinfo',
            #'-include','/usr/include/c++/' + env['gcc_version'] + '/memory',    #for auto_ptr
            #'-include','/usr/include/c++/' + env['gcc_version'] + '/algorithm', #for "sort"
        ]
        
        if env['gcc_version'] >= '4.6':
            env['CCFLAGS'] += ['-Werror=return-type'] # not supported yet in gcc 4.1
        
        #if env['gcc_version'] >= '4.6' and not env['use_clang'] and not env['use_clangsa']:
        #    env['CCFLAGS'] += ['-Werror']
        
        #export ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer-3.8
        #export ASAN_OPTIONS=alloc_dealloc_mismatch=0,symbolize=1
        
        if env['gcc_version'] >= '4.8':
            env['CCFLAGS'] += ['-fsanitize=address']
            env['LINKFLAGS'] += ['-fsanitize=address']

        if env['gcc_version'] >= '4.8':
            env['CCFLAGS'] += [
                '-D_FORTIFY_SOURCE=2',
                '-fstack-protector',
                '-Wno-error=maybe-uninitialized',
                '-Wno-unused-local-typedefs',
                '-Wno-conversion-null',
                '-Wno-invalid-offsetof',
            ]

        # If not set, -l order on command lines matter
        env['LINKFLAGS'] = [
            '-Wl,--no-as-needed',
        ]
        
        if env['gcc_version'] >= '4.6' and 'use_cpp11' in env and env['use_cpp11']:
            env['CCFLAGS'] += ['-std=c++0x', '-DCPLUSPLUS11']
            #'-std=gnu++98',
            #'-std=gnu++11',
            #'-std=gnu++0x',
            #'-std=c++0x',

        #if env['gcc_version'] >= '5.2':
        #    env['CCFLAGS'] += ['-D_GLIBCXX_USE_CXX11_ABI=0']

        #Activate for debug purpose (when we integrate and we have error with symbols resolutions)
        #env['LINKFLAGS'] = ['-Wl,-z,defs']
        
        env.Append(CORECFLAGS = '-Wextra')
        if 'use_gcov' in env and env['use_gcov']:
            #'-fprofile-generate',
            #'-fprofile-arcs',
            #'-ftest-coverage',
            env['CCFLAGS'] += ['--coverage']

        if 'use_gcov' in env and env['use_gcov']:
            env['LINKFLAGS'] += ['-g --coverage']
        
        #env.Append(LINKFLAGS = '-g --coverage')
    elif Arch in ['x86sol','sun4sol']:
        env['CCFLAGS'] = [
            '-features=no%conststrings,no%localfor',
            '-DOWTOOLKIT_WARNING_DISABLED',
            '-DP100',
            '-xildoff',
            '-DSYSV',
            '-DSVR4',
            '-Dsolaris',
            '-DANSI_C',
            '-D_TEMPLATES_ENABLE_',
            '-mt',
            '-D_POSIX_THREADS',
            '-D_REENTRANT',
            '-DuseTao',
            '-DACE_HAS_EXCEPTIONS',
        ]
        # If not set, -l order on command lines matter for static librairies
        env['LINKFLAGS'] = [
            '-zrescan',
        ]
    elif Arch in ['winnt','sun4sol']:
        env['debug_flags'] = [
            '/Zd',
            '/MDd',
        ]
        env['opt_flags'] = [
            '/O2',
            '/GL',
            '/MD',
        ]
        env['ENV']['PATH'] = env['ENV']['PATH'] + ';C:\\Program Files\\7-Zip;C:\\Program Files\\Java\\jre6\\bin'
        env['CCFLAGS'] = [
            '/nologo',
            '/W3',
            '/GX',
            '/GR',
            '-DWIN',
            '-DWIN32',
            '-DWINNT',
            '-D_WINDOWS',
        ]
        env['LINKFLAGS'] = [
            '/nologo',
            '/opt:ref',
            '/nodefaultlib:libcmt.lib',
            '/nodefaultlib:libc.lib',
            '/nodefaultlib:libcd.lib',
            '/nodefaultlib:libcmtd.lib',
        ]

    print "CCCOM is:", env.subst('$CCCOM')

def exists(env):
    return 1
