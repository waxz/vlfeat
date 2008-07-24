# file:        Makfile
# author:      Andrea Vedaldi
# description: Build everything

# AUTORIGHTS

# This makefile builds VLFeat on modern UNIX boxes with the GNU
# compiler and make programs. Mac and Linux are explicitly supported,
# and many other boxes should be easy to add.
#
# This makefile builds three components: VLFeat shared library (DLL),
# the command line programs, and the MATLAB toolbox. It also builds
# the documentation (for the API, the MATLAB toolbox, the command line
# utility, and also VLFeat homepage).
#
# Configuring the build system entails setting the appropriate
# variables, which are summarized next. The makefile attempts to
# auto-detect the right configuration parameters depending on the
# architecture (see later).
#
# == MISCELLANEOUS VARIABLES ==
#
# VER:          Package version (e.g. 1.0)
# DIST:         Package name for the source distr. ('vlfeat-1.0')
# BINDIST:      Package name for the binary distr. ('vlfeat-1.0-bin')
# HOST:         Where to pulbish the package.
# NDEBUG:       Set this flag to YES to remove debugging support
#
# == PROGRAMS REQUIRED FOR BUILDING ==
#
# The following programs are required to compile the C library and the
# command line utilities:
#
# CC:           C compiler (e.g. gcc).
# LIBTOOL:      libtool (used only under Mac)
#
# The following programs are required to compile the C code in the
# MATLAB Toolbox. Both are bundeld with MATLAB, but may not be
# available directly from the command line path.
#
# MATLAB:       Matlab executable (typically `matlab')
# MEX:          MEX compiler executable (typically `mex')
#
# The following programs are required to make the distribution
# packages:
#
# GIT:          Version system (you also need the full GIT repository).
#
# The following programs are needed only to generate the
# documentation:
#
# PYTHON:       Python interpreter
# DOXYGEN:      Doxygen documentation system
# DVIPNG:       TeX DVI to PNG converter
# DVIPS:        TeX DVI to PS converter
# EPS2PDF:      EPS to PDF converter
# CONVERT:      ImageMagik convert utility
# FIG2DEV:      X-Fig conversion program
#
# == BUILDING THE SHARED LIBRARY ==
#
# DLL_CLFAGS:   flags passed to $(CC) to compile a DLL C source
# DLL_SUFFIX:   suffix of a DLL (.so, .dylib)
# 
# == BUILDING THE COMMAND LINE UTILITIES ==
#
# BINDIR:       where to put the exec (and libraries)
# CLFAGS:       flags passed to $(CC) to compile a C source
# LDFLAGS:      flags passed to $(CC) to link C objects into an exec
#
# == BUILDING THE MEX FILES ==
#
# MATLABPATH:   MATALB root path
# MEX_BINDIR:   where to put mex files
# MEX_SUFFIX:   suffix of a MEX file (.mexglx, .mexmac, ...)
# MEX_FLAGS:    flags passed to $(MEX)
# MEX_CFLAGS:   flags added to the CLFAGS variable of $(MEX)
# MEX_LDFLAGS:  flags added to the LDFLAGS variable of $(MEX)
#
# == BUILDING THE DOCUMENTATION ==
#
# There are no configuration parameters.

NAME   := vlfeat
VER    := 0.9.1
HOST   := ganesh.cs.ucla.edu:/var/www/vlfeat
NDEBUG :=

.PHONY : all
all : dll all-bin all-mex

# --------------------------------------------------------------------
#                                                       Error Messages
# --------------------------------------------------------------------

err_no_arch  =
err_no_arch +=$(shell echo "** Unknown host architecture '$(UNAME)'. This identifier"   1>&2)
err_no_arch +=$(shell echo "** was obtained by running 'uname -sm'. Edit the Makefile " 1>&2)
err_no_arch +=$(shell echo "** to add the appropriate configuration."                   1>&2)
err_no_arch +=config

err_internal  =$(shell echo Internal error)
err_internal +=internal

# --------------------------------------------------------------------
#                                             Auto-detect Architecture
# --------------------------------------------------------------------

Darwin_PPC_ARCH             := mac
Darwin_Power_Macintosh_ARCH := mac
Darwin_i386_ARCH            := mci
Linux_i386_ARCH             := glx
Linux_i686_ARCH             := glx
Linux_unknown_ARCH          := glx
Linux_x86_64_ARCH           := g64

UNAME := $(shell uname -sm)
ARCH  := $($(shell echo "$(UNAME)" | tr \  _)_ARCH)

# sanity check
ifeq ($(ARCH),)
die:=$(error $(err_no_arch))
endif

# --------------------------------------------------------------------
#                                                            Functions
# --------------------------------------------------------------------

# $(call dump-var,VAR) prints the content of a variable VAR in
# two columns
define dump-var
@echo $(1) =
@echo $($(1)) | sed 's/\([^ ][^ ]* [^ ][^ ]*\) */\1#/g' | \
tr '#' '\n' | column -t | sed 's/\(.*\)/  \1/g'
endef

# $(call print-command, CMD, TGT)
define print-command
@printf "%10s %s\n" "$(strip $(1))" "$(strip $(2))"
endef

# $(call make-silent, CMD) makes the execution of the command $(CMD)
# silent
define make-silent
define $(strip $(1))
$(call print-command, $(1), "$$(@)")
@$($(strip $(1)))
endef
endef

# --------------------------------------------------------------------
#                                            Common UNIX Configuration
# --------------------------------------------------------------------

ifndef NDEBUG
DEBUG=yes
endif

CC              ?= cc
CONVERT         ?= convert
DOXYGEN         ?= doxygen
DVIPNG          ?= dvipng
DVIPS           ?= dvips
EPSTOPDF        ?= epstopdf
FIG2DEV         ?= fig2dev
GIT             ?= git
LATEX           ?= latex
LIBTOOL         ?= libtool
MATLAB          ?= matlab
MEX             ?= mex
PYTHON          ?= python

$(eval $(call make-silent, CC      ))
$(eval $(call make-silent, CONVERT ))
$(eval $(call make-silent, DOXYGEN ))
$(eval $(call make-silent, DVIPNG  ))
$(eval $(call make-silent, DVIPS   ))
$(eval $(call make-silent, EPSTOPDF))
$(eval $(call make-silent, FIG2DEV ))
$(eval $(call make-silent, LATEX   ))
$(eval $(call make-silent, LIBTOOL ))
$(eval $(call make-silent, MEX     ))

CFLAGS          += -I$(CURDIR) -pedantic 
CFLAGS          += -Wall -std=c89 -O3
CFLAGS          += -Wno-unused-function 
CFLAGS          += -Wno-long-long
CFLAGS          += $(if $(DEBUG), -O0 -g)
LDFLAGS         += -L$(BINDIR) -l$(DLL_NAME)

DLL_NAME         = vl
DLL_CFLAGS       = $(CFLAGS) -fvisibility=hidden -fPIC -DVL_BUILD_DLL

MEX_CFLAGS       = $(CFLAGS) -Itoolbox
MEX_LDFLAGS      = -L$(BINDIR) -l$(DLL_NAME)

# --------------------------------------------------------------------
#                                  Architecture-specific Configuration
# --------------------------------------------------------------------

# Mac OS X on PPC processor
ifeq ($(ARCH),mac)
BINDIR          := bin/mac
DLL_SUFFIX      := dylib
MEX_SUFFIX      := mexmac
CFLAGS          += -D__BIG_ENDIAN__ -Wno-variadic-macros 
CLFAGS          += $(if $(DEBUG), -gstabs+)
LDFLAGS         += -lm
DLL_CFLAGS      += -fvisibility=hidden
MATLABPATH      ?= $(dir $(shell readlink `which mex`))/..
MEX_FLAGS       += -lm CC='gcc' CXX='g++' LD='gcc'
MEX_CFLAGS      += 
MEX_LDFLAGS     +=
endif

# Mac OS X on Intel processor
ifeq ($(ARCH),mci)
BINDIR          := bin/maci
DLL_SUFFIX      := dylib
MEX_SUFFIX      := mexmaci
CFLAGS          += -D__LITTLE_ENDIAN__ -Wno-variadic-macros
CFLAGS          += $(if $(DEBUG), -gstabs+)
LDFLAGS         += -lm
MATLABPATH      ?= $(dir $(shell readlink `which mex`))/..
MEX_FLAGS       += -lm
MEX_CFLAGS      += 
MEX_LDFLAGS     += 
endif

# Linux-32
ifeq ($(ARCH),glx)
BINDIR          := bin/glx
MEX_SUFFIX      := mexglx
DLL_SUFFIX      := so
CFLAGS          += -D__LITTLE_ENDIAN__ -std=c99
LDFLAGS         += -lm -Wl,--rpath,\$$ORIGIN/
MATLABPATH      ?= $(dir $(shell readlink -f `which mex`))/..
MEX_FLAGS       += -lm
MEX_CFLAGS      += 
MEX_LDFLAGS     += -Wl,--rpath,\\\$$ORIGIN/
endif

# Linux-64
ifeq ($(ARCH),g64)
BINDIR          := bin/g64
MEX_SUFFIX      := mexa64
DLL_SUFFIX      := so
CFLAGS          += -D__LITTLE_ENDIAN__ -std=c99
LDFLAGS         += -lm -Wl,--rpath,\$$ORIGIN/
MATLABPATH      ?= $(dir $(shell readlink -f `which mex`))/..
MEX_FLAGS       += -lm
MEX_CFLAGS      += 
MEX_LDFLAGS     += -Wl,--rpath,\\\$$ORIGIN/
endif

DIST            := $(NAME)-$(VER)
BINDIST         := $(DIST)-bin
MEX_BINDIR      := toolbox/$(MEX_SUFFIX)

# Sanity check
ifeq ($(DLL_SUFFIX),)
die:=$(error $(err_internal))
endif

# --------------------------------------------------------------------
#                                                     Make directories
# --------------------------------------------------------------------

.PRECIOUS: %/.dirstamp
%/.dirstamp :
	@printf "%10s %s\n" MK "$(dir $@)"
	@mkdir -p $(dir $@)
	@echo "Directory generated by make." > $@

define gendir
$(1)-dir=$(foreach x,$(2),$(x)/.dirstamp)
endef

$(eval $(call gendir, doc,     doc doc/demo doc/figures             ))
$(eval $(call gendir, results, results                              ))
$(eval $(call gendir, bin,     $(BINDIR) $(BINDIR)/objs             ))
$(eval $(call gendir, mex,     $(MEX_BINDIR)                        ))

# --------------------------------------------------------------------
#                                                  Build shared library
# --------------------------------------------------------------------
#
# Objects and dependecies are placed in the $(BINDIR)/objs/
# directory. The makefile creates a static and a dynamic version of
# the library. Depending on the architecture, one or more of the
# following files are produced:
#
# $(OBJDIR)/libvl.so      ELF dynamic library (Linux)
# $(OBJDIR)/libvl.dylib   Mach-O dynamic library (Mac OS X)
#
# == Note on Mac OS X ==
#
# On Mac we set the install name of the library to look in
# @loader_path/.  This means that any binary linked (either an
# executable or another DLL) will search in his own directory for a
# copy of libvl (this behaviour can then be changed by
# install_name_tool).

dll_tgt := $(BINDIR)/lib$(DLL_NAME).$(DLL_SUFFIX)
dll_src := $(wildcard vl/*.c)
dll_hdr := $(wildcard vl/*.h) $(wildcard vl/*.tc)
dll_obj := $(addprefix $(BINDIR)/objs/, $(notdir $(dll_src:.c=.o)))
dll_dep := $(dll_obj:.o=.d)

.PHONY: dll
dll: $(dll_tgt)

.PRECIOUS: $(BINDIR)/objs/%.d

$(BINDIR)/objs/%.o : vl/%.c $(bin-dir)
	$(CC) $(DLL_CFLAGS) -c $< -o $@

$(BINDIR)/objs/%.d : vl/%.c $(bin-dir)
	$(CC) $(DLL_CFLAGS)                                          \
	       -M -MT '$(BINDIR)/objs/$*.o $(BINDIR)/objs/$*.d'      \
	       $< -MF $@

$(BINDIR)/lib$(DLL_NAME).dylib : $(dll_obj)
	@$(LIBTOOL) -dynamic                                         \
                    -flat_namespace                                  \
                    -install_name @loader_path/libvl.dylib           \
	            -compatibility_version $(VER)                    \
                    -current_version $(VER)                          \
	            -o $@ -undefined suppress $^

$(BINDIR)/lib$(DLL_NAME).so : $(dll_obj)
	$(CC) $(DLL_CFLAGS) -shared $(^) -o $(@)

# --------------------------------------------------------------------
#                                         Build command line utilities
# --------------------------------------------------------------------
# The executables are stored in $(BINDIR). $(dll_tgt) is not a direct
# dependency in order avoiding rebuilding all the executables if only
# a part of the library is changed.

bin_src := $(wildcard src/*.c)
bin_tgt := $(notdir $(bin_src))
bin_tgt := $(addprefix $(BINDIR)/, $(bin_tgt:.c=))
bin_dep := $(addsuffix .d, $(bin_tgt))

.PHONY: all-bin
all-bin: $(bin_tgt)

$(BINDIR)/% : src/%.c $(bin-dir)
	@make -s $(dll_tgt)
	$(CC) $(CFLAGS) $< $(LDFLAGS) -o $@

$(BINDIR)/%.d : src/%.c $(bin-dir)
	$(CC) $(CFLAGS) -M -MT                                        \
	       '$(BINDIR)/$* $(MEX_BINDIR)/$*.d'                      \
	       $< -MF $@

# --------------------------------------------------------------------
#                                                      Build MEX files
# --------------------------------------------------------------------
# MEX files are placed in toolbox/$(MEX_SUFFIX). MEX files are linked
# so that they search for the dynamic libvl in the directory where
# they are found. A link is automatically created to the library
# binary file.
#
# On Linux, this is obtained by setting -rpath to $ORIGIN/ for each
# MEX file. On Mac OS X this is implicitly obtained since libvl.dylib
# has install_name relative to @loader_path/.

mex_src := $(shell find toolbox -name "*.c")
mex_tgt := $(addprefix $(MEX_BINDIR)/,                               \
	   $(notdir $(mex_src:.c=.$(MEX_SUFFIX)) ) )
mex_dep := $(mex_tgt:.$(MEX_SUFFIX)=.d)

vpath %.c $(shell find toolbox -type d)

.PHONY: all-mex
all-mex : $(mex_tgt)

$(MEX_BINDIR)/%.d : %.c $(mex-dir)
	$(CC) $(MEX_CFLAGS)                                          \
               -I$(MATLABPATH)/extern/include -M -MT                 \
	       '$(MEX_BINDIR)/$*.$(MEX_SUFFIX) $(MEX_BINDIR)/$*.d'   \
	       $< -MF $@

$(MEX_BINDIR)/%.$(MEX_SUFFIX) : %.c $(mex-dir)
	@make -s $(dll_tgt)
	$(MEX) CFLAGS='$$CFLAGS  $(MEX_CFLAGS)'                      \
	       LDFLAGS='$$LDFLAGS $(MEX_LDFLAGS)'                    \
	       $(MEX_FLAGS)                                          \
	       $< -outdir $(dir $(@))
	@test -e $(MEX_BINDIR)/lib$(DLL_NAME).$(DLL_SUFFIX) ||       \
	 ln -sf ../../$(BINDIR)/lib$(DLL_NAME).$(DLL_SUFFIX)         \
	        $(MEX_BINDIR)/lib$(DLL_NAME).$(DLL_SUFFIX)

# --------------------------------------------------------------------
#                                                  Build documentation
# --------------------------------------------------------------------

.PHONY: doc, doc-figures, doc-api, doc-toolbox
.PHONY: doc-web, doc-demo
.PHONY: doc-bindist, doc-distclean
.PHONY: autorights

m_src    := $(shell find toolbox -name "*.m")
fig_src  := $(wildcard docsrc/figures/*.fig)
demo_src := $(wildcard doc/demo/*.eps)
html_src := $(wildcard docsrc/*.html)

pdf_tgt := #$(fig_src:.fig=.pdf) 
eps_tgt := #$(subst docsrc/,doc/,$(fig_src:.fig=.eps))
png_tgt := $(subst docsrc/,doc/,$(fig_src:.fig=.png))
jpg_tgt := $(demo_src:.eps=.jpg)
img_tgt := $(jpg_tgt) $(png_tgt) $(pdf_tgt) $(eps_tgt)

VERSION:
	echo "Version $(VER) (`date`)" > VERSION

doc: doc-api doc-web
doc-api: doc/api/index.html
doc-web: doc/index.html
doc-toolbox: doc/toolbox-src/mdoc.html

doc-deep: all $(doc-dir) $(results-dir)
	cd toolbox ; \
	$(MATLAB) -nojvm -nodesktop -r 'vlfeat_setup;demo_all;exit'


#
# Use webdoc.py to generate the website
#

doc/index.html: doc/toolbox-src/mdoc.html $(html_src) \
 docsrc/web.xml docsrc/web.css docsrc/webdoc.py $(img_tgt)
	$(PYTHON) docsrc/webdoc.py --outdir=doc \
	     docsrc/web.xml --verbose
	rsync -arv docsrc/images doc

#
# Use mdoc.py to create the toolbox documentation that will be
# embedded in the website.
#

doc/toolbox-src/mdoc.html : $(m_src)
	$(PYTHON) docsrc/mdoc.py toolbox doc/toolbox-src --format=web

#
# Generate the customized API documentation
#

doc/doxygen_header.html doc/doxygen_footer.html: doc/index.html
	cat doc/api/api.html | \
	sed -n '/<!-- Doc Here -->/q;p'  > doc/doxygen_header.html
	cat doc/api/api.html | \
	sed -n '/<!-- Doc Here -->/,$$p' > doc/doxygen_footer.html

doc/api/index.html: docsrc/doxygen.conf VERSION $(img_tgt)            \
  $(dll_src) $(dll_hdr) $(img_tgt)                                    \
  doc/doxygen_header.html doc/doxygen_footer.html
	$(DOXYGEN) $<

#
# Figure conversion
#

doc/figures/%.png : doc/figures/%.dvi
	$(DVIPNG) -D 75 -T tight -o $@ $<

doc/figures/%.eps : doc/figures/%.dvi
	$(DVIPS) -E -o $@ $<

doc/figures/%-raw.tex : docsrc/figures/%.fig
	$(FIG2DEV) -L pstex_t -p doc/figures/$*-raw.ps $< $@ 

doc/figures/%-raw.ps : docsrc/figures/%.fig
	$(FIG2DEV) -L pstex $< $@

doc/figures/%.dvi doc/figures/%.aux doc/figures/%.log :  \
  doc/figures/%.tex doc/figures/%-raw.tex doc/figures/%-raw.ps $(doc-dir)
	$(LATEX) -output-directory=$(dir $@) $<

doc/figures/%.tex : $(doc-dir)
	@$(print-command GEN, $@)
	@/bin/echo '\documentclass[landscape]{article}' >$@
	@/bin/echo '\usepackage[margin=0pt]{geometry}' >>$@
	@/bin/echo '\usepackage{graphicx,color}'       >>$@
	@/bin/echo '\begin{document}'                  >>$@
	@/bin/echo '\pagestyle{empty}'                 >>$@
	@/bin/echo '\input{doc/figures/$(*)-raw.tex}'  >>$@
	@/bin/echo '\end{document}'	               >>$@

doc/demo/%.jpg : doc/demo/%.eps
	$(CONVERT) -density 400 $< -colorspace rgb -resize 20% jpg:$@

doc/demo/%.png : doc/demo/%.eps
	$(CONVERT) -density 400 $< -colorspace rgb -resize 20% png:$@

doc/%.pdf : doc/%.eps
	$(EPSTOPDF) --outfile=$@ $<


doc-bindist: $(NAME) doc
	rsync -arv doc $(NAME)/                                      \
	  --exclude=doc/demo/*.eps                                   \
	  --exclude=doc/toolbox-src*

doc-distclean:
	rm -f  docsrc/*.pyc
	rm -rf doc

doc-wiki: $(NAME) 
	$(PYTHON) doc/mdoc.py --wiki toolbox doc/wiki

autorights: distclean
	autorights                                                   \
	  toolbox vl                                                 \
	  --recursive                                                \
	  --verbose                                                  \
	  --template doc/copylet.txt                                 \
	  --years 2007                                               \
	  --authors "Andrea Vedaldi and Brian Fulkerson"             \
	  --holders "Andrea Vedaldi and Brian Fulkerson"             \
	  --program "VLFeat"

# --------------------------------------------------------------------
#                                                           Make clean
# --------------------------------------------------------------------

.PHONY: clean, distclean

clean:
	rm -f  `find . -name '*~'`
	rm -f  `find . -name '.DS_Store'`
	rm -f  `find . -name '.gdb_history'`
	rm -f  `find . -name '._*'`
	rm -rf `find ./bin -name 'objs' -type d`
	rm -rf  ./results
	rm -rf $(NAME)

distclean: clean doc-distclean
	rm -rf bin
	for i in mexmac mexmaci mexglx mexw32 mexa64 ;               \
	do                                                           \
	   rm -rf "toolbox/$${i}" ;                                  \
	done
	rm -f $(NAME)-*.tar.gz

# --------------------------------------------------------------------
#                                          Build distribution packages
# --------------------------------------------------------------------

.PHONY: $(NAME), dist, bindist
.PHONY: post, post-doc

$(NAME): VERSION
	rm -rf $(NAME)
	$(GIT) archive --prefix=$(NAME)/ HEAD | tar xvf -
	rsync -arv VERSION $(NAME)/

dist: $(NAME)
	COPYFILE_DISABLE=1                                           \
	COPY_EXTENDED_ATTRIBUTES_DISABLE=1                           \
	tar czvf $(DIST).tar.gz $(NAME)

bindist: $(NAME) all doc-bindist
	rsync -arv --exclude=objs --exclude=*.pdb bin $(NAME)/
	rsync -arv --include=*mexmaci                                \
	           --include=*mexmac                                 \
	           --include=*.dylib                                 \
	           --include=*.so                                    \
	           --include=*mexw32                                 \
	           --include=*mexglx                                 \
	           --include=*mexa64                                 \
	           --include=*dll                                    \
		   --exclude=*                                       \
	           toolbox/ $(NAME)/toolbox 
	tar czvf $(BINDIST).tar.gz $(NAME)/


post:
	rsync -aP $(DIST).tar.gz $(BINDIST).tar.gz                   \
	    $(HOST)/download

post-doc: doc
	rsync -aP --exclude=*.eps doc/ $(HOST)

# --------------------------------------------------------------------
#                                               Automatic Dependencies
# --------------------------------------------------------------------

ifeq ($(filter doc clean distclean info, $(MAKECMDGOALS)),)
include $(dll_dep) $(bin_dep) $(mex_dep)
endif

# --------------------------------------------------------------------
#                                                       Debug Makefile
# --------------------------------------------------------------------

.PHONY: info
info :
	$(call dump-var,dll_hdr)
	$(call dump-var,dll_src)
	$(call dump-var,dll_obj)
	$(call dump-var,dll_dep)
	$(call dump-var,mex_src)
	$(call dump-var,fig_src)
	$(call dump-var,demo_src)
	$(call dump-var,mex_tgt)
	$(call dump-var,bin_src)
	$(call dump-var,bin_tgt)
	$(call dump-var,bin_dep)
	$(call dump-var,pdf_tgt)
	$(call dump-var,eps_tgt)
	$(call dump-var,png_tgt)
	$(call dump-var,jpg_tgt)
	@echo "ARCH         = $(ARCH)"
	@echo "DIST         = $(DIST)"
	@echo "BINDIST      = $(BINDIST)"
	@echo "MEX_BINDIR   = $(MEX_BINDIR)"
	@echo "DLL_SUFFIX   = $(DLL_SUFFIX)"
	@echo "MEX_SUFFIX   = $(MEX_SUFFIX)"
	@echo "CFLAGS       = $(CFLAGS)"
	@echo "LDFLAGS      = $(LDFLAGS)"
	@echo "MATLAB       = $(MATLAB)"
	@echo "MEX_FLAGS    = $(MEX_FLAGS)"
	@echo "MEX_CFLAGS   = $(MEX_CFLAGS)"
	@echo "MEX_LDFLAGS  = $(MEX_LDFLAGS)"
	@printf "\nThere are %s lines of code.\n" \
	`cat $(m_src) $(mex_src) $(dll_src) $(dll_hdr) $(bin_src) | wc -l`

# --------------------------------------------------------------------
#                                                        Xcode Support
# --------------------------------------------------------------------

.PHONY: dox-
dox- : dox

.PHONY: dox-clean
dox-clean:
