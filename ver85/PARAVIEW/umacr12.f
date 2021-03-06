﻿!$Id:$
      subroutine umacr12(lct,ctl)

!      for F E A P -- A Finite Element Analysis Program
!
!      coded by:
!                B.Sc. Henning Venghaus
!                Institute of Mechanics
!                Otto von Guericke University
!                Spring 2017

!-----[--.----+----.----+----.-----------------------------------------]
!     Modification log                                Date (dd/mm/year)
!       Original version                                    02/03/2017
!       1.anisotropic element subdivision                   26/03/2017
!       2. Update to ver8.5                                 03/07/2017
!       3. Added calls to new routines for igafeap          03/03/2018
!       4. Added output for Bezier elements of Paraview     08/06/2020
!-----[--.----+----.----+----.-----------------------------------------]
!      Purpose:  driver for Uparaview Nurb and FE Output routines
!
!      Inputs:
!        lct    - usage specifier (see documentation)
!        ctl(3) - usage parameter (see documentation)
!      Outputs:
!        depending on user commands
!-----[--.----+----.----+----.-----------------------------------------]
      implicit  none


      include  'cdata.h'
      include  'comfil.h'
      include  'counts.h'
      include  'eldatp.h'
      include  'iofile.h'
      include  'pointer.h'
      include  'sdata.h'
      include  'strnum.h'
      include  'umac1.h'
      include  'comblk.h'
      include  'cnurb.h'
      include  'pdata3.h'
      include  'npvi.h'
      include  'prstrs.h'
      include  'fdata.h'


      logical   pcomp, setvar, palloc, ualloc
      character lct*15
      real*8    ctl(3)
      logical timefl, strefl, velofl, accefl, histfl, helpfl
      logical feopfl, distfl, quadfl, mergfl
      integer fe_el_typ, npl_int_inp, npl_int_old
      integer bez_el_typ
      integer ne_export, nd_export
      integer nen1_export, nen_export
      integer i,dbglvl
      integer numnmsv


      save

!     Set command word

      if(pcomp(uct,'ma12',4)) then      ! Usual    form
        uct = 'npvi'                    ! NURBS pvie
      elseif(urest.eq.1) then           ! Read  restart data

      elseif(urest.eq.2) then           ! Write restart data

      else                              ! Perform user operation


      if (index(lct,'nusd').ne.0) then
        nusdfl = .True.
        if (.True.) write(*,4402) 'Parameter for non-uniform'//
     &    'subdivision is read and stored'

        do i=1,3
        if (nint(ctl(i)).ne.0) then
          npl_int_nusd(i) = nint(ctl(i))
        else
          npl_int_nusd(i) = 1
        end if
        end  do !i

        if (.True.) write(*,4403) 'anisotropic subdivision X:',
     &                                   npl_int_nusd(1)
        if (.True.) write(*,4403) 'anisotropic subdivision Y:',
     &                                   npl_int_nusd(2)
        if (.True.) write(*,4403) 'anisotropic subdivision Z:',
     &                                   npl_int_nusd(3)
        if (max(npl_int_nusd(1),npl_int_nusd(2),
     &                      npl_int_nusd(3)).gt.7) then
          write(*,4404) 'Warning! subdivision factor greater then 7!!'
        end if

        if (.True.) write(*,4402) 'routine stops here!'
        goto 70

      end if !(index(lct,'nusd').ne.0) then

      dbglvl = nint(ctl(3))
!       dbglvl: 0   -> no output
!       dbglvl: 1   -> status output
!       dbglvl: 2   -> info output

      if (dbglvl.ge.1) write(*,4401) 'NPVI invoked - now running'

      helpfl = .False.
      timefl = .False.
      strefl = .False.
      velofl = .False.
      accefl = .False.
      histfl = .False.
      distfl = .True.
      feopfl = .False.
      serefl = .False.
      mergfl = .True.

      if (pcomp(lct,'help',4)) then
        helpfl = .True.
      end if !(index('help',lct).ne.0)

      if (helpfl) then
!       display help
        call npvihelpmsg()
!       exit subroutine
        write(*,4401) 'NPVI aborted'
        goto 70

      end if !helpfl

      if (pcomp(lct,'comp',4)) then
!       call the corresponding subroutine
        call npvi_python()
!       exit subroutine
        write(*,4400) 'npvi_vtkcomp.py is successfully created'
        write(*,4400) 'remember to run: "pvpython npvi_vtkcomp.py"'
        goto 70

      end if !helpfl

      if (index(lct,'t').ne.0) then
        timefl = .True.
      end if !(index('t',lct).ne.0)

      if (index(lct,'s').ne.0) then
        strefl = .True.
      end if !(index('s',lct).ne.0)

      if (index(lct,'v').ne.0) then
        velofl = .True.
      end if !(index('v',lct).ne.0)

      if (index(lct,'a').ne.0) then
        accefl = .True.
      end if !(index('a',lct).ne.0)

      if (index(lct,'h').ne.0) then
        histfl = .True.
      end if !(index('h',lct).ne.0)

      if (index(lct,'m').ne.0) then
        mergfl = .False.
        if (dbglvl.ge.2) write(*,4402) 
     &   'Merging control points - disabled (mergfl)'
      end if !(index('h',lct).ne.0)

      if (pcomp(lct,'feop',4)) then
        feopfl = .True.
        !if feop cmd was given - set feopfl true
        !set all other flags false
        timefl=.False.
        strefl=.False.
        velofl=.False.
        accefl=.False.
        histfl=.False.
        distfl=.False.
      end if !(index(lct,'feop').ne.0) then


!-----|read first parameter for element type                         |
!-----|blank,0,1 -> linear element                                   |
!-----|        2 -> quadratic element (serendipity)                  |
!-----|        3 -> quadratic element (lagrange, only for FEoutput)  |
!-----|        4 -> Bezier elements                                  |
      if (nint(ctl(1)).le.1 ) then
        fe_el_typ = 1
        quadfl = .False.
        if (dbglvl.ge.2) write(*,4402) 'FE-element Type is linear'
      elseif (nint(ctl(1)).eq.2) then
        fe_el_typ = 2
        quadfl = .True.
        serefl = .True.
        if (dbglvl.ge.2) write(*,4402) 'FE-element Type is quadratic,'
     &                                 //' serendipity element'
      elseif (nint(ctl(1)).eq.3) then
        fe_el_typ = 2
        quadfl = .True.
        if (.not.feopfl) then
          write(*,4401) 'lagrange elements only for feap output!'
          write(*,4401) 'NPVI aborted'
          goto 70
        end if !(.not.feopfl)

        if (dbglvl.ge.2) write(*,4402) 'FE-element Type is quadratic,'
     &                                 //' lagrange element'
      elseif (nint(ctl(1)).eq.4) then
        fe_el_typ = 0
        bez_el_typ = 1
        quadfl = .False.

        if (dbglvl.ge.2) write(*,4402) 'Bezier element type activated.'

      end if ! ctl(1) 1 or 2 or 3 or 4

      npl_int_inp = nint(ctl(2))
      npl_int_old = npl_int

      if (npl_int_inp.gt.7) then
          write(*,4404) 'Warning! subdivision factor greater then 7!!'
        end if

      if (npl_int_inp.eq.0) then
!       anisotropic subdivision
        if (.not.nusdfl) then
          npl_int_nusd(1)=1
          npl_int_nusd(2)=1
          npl_int_nusd(3)=1
        end if

        if (dbglvl.ge.2) write(*,4403) 'anisotropic subdivision X:',
     &                                   npl_int_nusd(1)
        if (dbglvl.ge.2) write(*,4403) 'anisotropic subdivision Y:',
     &                                   npl_int_nusd(2)
        if (dbglvl.ge.2) write(*,4403) 'anisotropic subdivision Z:',
     &                                   npl_int_nusd(3)

      else if (npl_int_inp.ge.1) then
!       isotropic subdivision
        npl_int          = npl_int_inp
        do i=1,3
          if (i.le.ndm) then
            npl_int_nusd(i) = npl_int
          else
            npl_int_nusd(i) = 1
          end if!(i.le.ndm)
        end do!i

        if (dbglvl.ge.2) write(*,4403) 'isotropic subdivision:',
     &                                   npl_int
      end if
      if (dbglvl.ge.2) write(*,4403) 'FE el for each NURB el:',
     &                                   product(npl_int_nusd)

      if (dbglvl.ge.2) then
        write(*,4402) 'distfl: ',distfl
        write(*,4402) 'timefl: ',timefl
        write(*,4402) 'strefl: ',strefl
        write(*,4402) 'velofl: ',velofl
        write(*,4402) 'accefl: ',accefl
        write(*,4402) 'histfl: ',histfl
        write(*,4402) 'feopfl: ',feopfl
        write(*,4402) 'serefl: ',serefl
        write(*,4402) 'mergfl: ',mergfl
        write(*,4403) 'numnp:  ',numnp
        write(*,4403) 'npstr:  ',npstr
        write(*,4403) 'nen:    ',nen
        write(*,4403) 'nst:    ',nst
        write(*,4403) 'numel:  ',numel
        write(*,4403) 'istv:   ',istv
      endif !(dbglvl.ge.2)

! -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
!             L I N E A R
! -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      if (fe_el_typ.eq.1) then
!     RUN ALL NECESSARY (existing!) ROUTINES TO WRITE .vtu FILE (linar)

	fl(11) = .true.
      if (dbglvl.ge.1) write(*,4400) 'Start meshing'
!     MESH
      call pbezlin_nusd()
      if (dbglvl.ge.1) write(*,4401) 'Finished meshing'

!     prepare uparaview_nurb input values
      nd_export = nd_lin
      ne_export = ne_lin
      if (dbglvl.ge.2) write(*,4403) 'nd_lin:  ',nd_lin
      if (dbglvl.ge.2) write(*,4403) 'ne_lin:  ',ne_lin

      nen1_export = 19
      nen_export = nen1_export - 11


!     DISPLACEMENT
      if (distfl) then
!         if(np(278).eq.0) then
          setvar = palloc(278,'U_LIN',ndf*nd_lin,2)
!         endif

        if (dbglvl.ge.1) write(*,4400) 'Start projection of DISP'
c         Project displacements to linear nodes
        call pdis_lin_nusd_new(   mr(np(33)),
     &                            hr(np(43)),  hr(np(44)),
     &                            hr(np(263)), hr(np(264)),
     &                            hr(np(40)),  hr(np(278)),
     &                            mr(np(276)))

        if (dbglvl.ge.1) write(*,4401) 'Finished projection of DISP'
      end if !(distfl)

!     VELOCITY
      if (velofl .or. accefl) then
!       if(np(296).eq.0) then
        setvar = palloc(296,'V_LIN',2*ndf*nd_lin,2)
!       endif !np(296).eq.0
      endif !velofl .or. accefl

      if (velofl) then
!       Project velocities to linear nodes
          call pdis_lin_nusd_new( mr(np(33)),
     &                            hr(np(43)),  hr(np(44)),
     &                            hr(np(263)), hr(np(264)),
     &                            hr(np(42)),  hr(np(296)),
     &                            mr(np(276)))
      end if !velofl

      if (accefl) then
!       Project accelerations to linear nodes
          call pdis_lin_nusd_new( mr(np(33)),
     &                            hr(np(43)),  hr(np(44)),
     &                            hr(np(263)), hr(np(264)),
     &                            hr(np(42)+nneq), 
     &                            hr(np(296)+ndf*nd_lin),
     &                            mr(np(276)))
      end if !accefl

!     STRESSES
      if (strefl) then

        if (dbglvl.ge.1) write(*,4400) 'Start projection of STRE'
        if (dbglvl.ge.1) write(*,4400) 'Start projection of PSTR'

        setvar = ualloc(11,'UTEM1',2*nd_lin,1)

        call proj_matc(mr(np(276)),8,19,ne_lin, mr(up(11)),
     &                   nd_lin,numni)

        setvar = palloc(341,'MIGPT',nd_lin+1,1)
        setvar = palloc(342,'MIGVA',numni  ,1)      
        call proj_mats(mr(np(276)),8,19,ne_lin, mr(up(11)),
     &                   mr(np(341)),nd_lin, mr(np(342)))

        setvar = ualloc(11,'UTEM1',0,1)


        setvar = ualloc(11,'UTEM1',2*numnp,1)
        call proj_matc(mr(np(33)),nen,nen1,
     &                 numel, mr(up(11)),
     &                 numnp,numnm)

        setvar = palloc(339,'MAPTR',numnp+1,1)
        setvar = palloc(340,'MAVAL',numnp  ,1)  
        call proj_mats(mr(np(33)),nen,nen1,
     &                 numel, mr(up(11)),
     &                 mr(np(339)),numnp, mr(np(340)))
        setvar = ualloc(11,'UTEM1',0,1)

        call pjstrs_lin(.false.) 

        if (dbglvl.ge.1) write(*,4401) 'Finished projection of STRE'
        if (dbglvl.ge.1) write(*,4401) 'Finished projection of PSTR'


      end if ! strefl



! -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
!             Q U A D R A T I C
! -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      else if (fe_el_typ.eq.2) then
!     RUN ALL NECESSARY (new!)      ROUTINES TO WRITE .vtu FILE (quad)


      if (dbglvl.ge.1) write(*,4400) 'Start meshing'
!     MESH
      call pbezquad_nusd() !in this file
      if (dbglvl.ge.1) write(*,4401) 'Finished meshing'


!     prepare uparaview_nurb input values
      nd_export = nd_quad
      ne_export = ne_quad


!     DISPLACEMENT
      if (distfl) then
!         if(np(278).eq.0) then
          setvar = palloc(278,'U_LIN',ndf*nd_quad,2)
!         endif
        if (dbglvl.ge.1) write(*,4400) 'Start projection of DISP'
        call pdis_quad_nusd_new(  mr(np(33)),
     &                            hr(np(43)),  hr(np(44)),
     &                            hr(np(263)), hr(np(264)),
     &                            hr(np(40)),  hr(np(278)),
     &                            mr(np(276)))
        if (dbglvl.ge.1) write(*,4401) 'Finished projection of DISP'
      end if !(distfl)

!     VELOCITY
      if (velofl .or. accefl) then
!       if(np(296).eq.0) then
        setvar = palloc(296,'V_LIN',2*ndf*nd_quad,2)
!       endif !np(296).eq.0
      endif !velofl .or. accefl

      if (velofl) then
!       Project velocities to quadratic nodes
          call pdis_quad_nusd_new(mr(np(33)),
     &                        hr(np(43)),  hr(np(44)),
     &                        hr(np(263)), hr(np(264)),
     &                        hr(np(42)),  hr(np(296)),
     &                        mr(np(276)))
      end if !velofl

      if (accefl) then
!       Project accelerations to quadratic nodes
          call pdis_quad_nusd_new(mr(np(33)),
     &                        hr(np(43)),  hr(np(44)),
     &                        hr(np(263)), hr(np(264)),
     &                        hr(np(42)+nneq), hr(np(296)+ndf*nd_quad),
     &                        mr(np(276)))
      end if !accefl

!     STRESSES
      if (strefl) then

        if (dbglvl.ge.1) write(*,4400) 'Start projection of STRE'
        if (dbglvl.ge.1) write(*,4400) 'Start projection of PSTR'

        setvar = ualloc(11,'UTEM1',2*nd_quad,1)

        call proj_matc(mr(np(276)),20,31,ne_quad, mr(up(11)),
     &                   nd_quad,numni)

        setvar = palloc(341,'MIGPT',nd_quad+1,1)
        setvar = palloc(342,'MIGVA',numni  ,1)      
        call proj_mats(mr(np(276)),20,31,ne_quad, mr(up(11)),
     &                   mr(np(341)),nd_quad, mr(np(342)))

        setvar = ualloc(11,'UTEM1',0,1)


        setvar = ualloc(11,'UTEM1',2*numnp,1)
        call proj_matc(mr(np(33)),nen,nen1,
     &                 numel, mr(up(11)),
     &                 numnp,numnm)

        setvar = palloc(339,'MAPTR',numnp+1,1)
        setvar = palloc(340,'MAVAL',numnp  ,1)  
        call proj_mats(mr(np(33)),nen,nen1,
     &                 numel, mr(up(11)),
     &                 mr(np(339)),numnp, mr(np(340)))
        setvar = ualloc(11,'UTEM1',0,1)

        call pjstrs_quad(.false.) 

        if (dbglvl.ge.1) write(*,4401) 'Finished projection of STRE'
        if (dbglvl.ge.1) write(*,4401) 'Finished projection of PSTR'
      end if ! strefl



      write(*,4403) 'nd_quad:  ',nd_quad
      write(*,4403) 'ne_quad:  ',ne_quad

      if (serefl) then
        nen1_export = 31
        nen_export = nen1_export -11
      else
        nen1_export = 38
        nen_export = nen1_export -11
      end if !serefl

! -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
!             B E Z I E R
! -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      else if (fe_el_typ.eq.0 .and. bez_el_typ.eq.1) then
!     RUN ALL NECESSARY (existing!) ROUTINES TO WRITE .vtu FILE (linar)
      call bezier_driver(timefl, strefl, velofl, accefl, histfl,
     &                   mergfl, helpfl, dbglvl)

      go to 70
      
      end if ! run meshing and interpolating routines for lin. or quad.
! -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

!       Allocate array to store element offset pointers
      setvar = ualloc(11,'UTEM1',ne_export+1,1)
!     common npvi use:
!     RUN PARAVIEW FILE CREATING ROUTINE
!        call pzero(hr(np(281)),nd_lin*npstr)
!        hr(np(281)+nd_export:np(281)+nd_export+15) = 1
      if (.not. feopfl) then
        numnmsv = numnm
        numnm   = numni

        call uparaview_nurb(
     &              hr(np(277)),      !x(ndm,numnp)     - Node coordinat
     &              mr(np(276)),      !ix(nen1,numel)   - Element connec
     &              hr(np(278)),      !u(ndf,numnp)     - Node displacem
     &              hr(np(296)),      !ud(ndf,numel,2)  - Node velocity
     &              hr(np(281)+numni), !sig(numnp,*)     - Node stre
     &              hr(np(282)+numni), !psig(numnp,*)    - Node prin
     &              hr(np(305)),      !his(numnp,*)     - History variab
     &              mr(up(11)),       !el_ptr(numel+1)  - Pointer to ele
     &              mr(np(341)),      !ip(0:numnp)      - Pointer to sig
     &              ndm,              !ndm              - Mesh dimension
     &              ndf,              !ndf              - DOF's/node
     &              nen1_export,      !nen1             - Dimension of i
     &              nen_export,       !nen              - Max nodes/elem
     &              hplmax,           !hplmax           - Number of hist
     &              nd_export,        !nd_export        - Number of node
     &              ne_export,        !ne_export        - Number of elem
     &              timefl,           !                 - Time Flag
     &              strefl,           !                 - Stress Flag
     &              velofl,           !                 - Velocity Flag
     &              accefl,           !                 - Acceleration F
     &              histfl,           !                 - History Flag
     &              dbglvl,           !                 - debug level
     &              quadfl)           !                 - true if quad 

        numnm = numnmsv

      else
!     RUN FE OUTPUT FILE CREATING ROUTINE
        call FEoutput(
     &              hr(np(277)),      !x(ndm,numnp)     - Node coordinat
     &              mr(np(276)),      !ix(nen1,numel)   - Element connec
     &              ndm,              !ndm              - Mesh dimension
     &              nen1_export,      !nen1             - Dimension of i
     &              nen_export,       !nen              - Max nodes/elem
     &              nd_export,        !nd_export        - Number of node
     &              ne_export,        !ne_export        - Number of elem
     &              quadfl)           !quadfl           - True if quadra

      end if !(not feopfl)

!     Deallocate temporary array
      setvar = ualloc(11,'UTEM1',0 ,1)
!      setvar = palloc(278, 'U_LIN',0 ,2)
!      setvar = palloc(276, 'I_LIN',0 ,1)     ! IX_LIN
!      setvar = palloc(277, 'X_LIN',0 ,2)     ! X_LIN
!      setvar = palloc(281, 'S_LIN',0 ,2) ! s_lin
!      setvar = palloc(282, 'P_LIN',0 ,2) ! p_lin
!      if(histpltfl) then
!        setvar = palloc(306, 'H_LIN',0 ,2) ! h_lin
!      endif
!      setvar = palloc( 57,'NDER',0 ,2)
!      setvar = palloc( 58,'NDNP',0 ,2)
!      if(histpltfl) then
!        setvar = palloc(305,'HDNP ',0 ,2)
!      endif

!      setvar = palloc( 60,'NDNS',0 ,2)
!      setvar = palloc(207,'NSCR',0 ,2)
!      if(histpltfl) then
!        setvar = palloc(304,'HSELM',0 ,2)
!      endif

!        setvar = palloc(339,'MAPTR',0 ,1)
!        setvar = palloc(340,'MAVAL',0 ,1)  
!        setvar = palloc(341,'MIGPT',0 ,1)
!        setvar = palloc(342,'MIGVA',0 ,1) 
!      setvar = palloc(281, 'S_LIN', 0, 2) ! s_lin
!      setvar = palloc(282, 'P_LIN', 0, 2) ! p_lin

      npl_int = npl_int_old

      end if ! pcomp(uct,'ma12',4)

      if (dbglvl.ge.1) write(*,4401) 'NPVI completed'

      if (max(npl_int_nusd(1),npl_int_nusd(2),
     &                      npl_int_nusd(3)).gt.7) then
          write(*,4404) '*****'
          write(*,4404) 'Warning! subdivision factor greater then 7!!'
          write(*,4404) '*****'
      end if

 70   continue
      return

!     Formats

4400  format('[....] ',a)
4401  format('[ OK ] ',a)
4402  format('[info] ',a,L2)
4403  format('[info] ',a,i7)
4404  format('[warn] ',a)

      end subroutine umacr12
