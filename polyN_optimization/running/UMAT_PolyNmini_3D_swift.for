!DIR$ FREEFORM
!CC*******************************************************************************
!C  UMAT: developed by S.C. Soare. 
!C  IT USES ISOTROPIC ELASTICITY COUPLED WITH AN ANISOTROPIC YIELD FUNCTION. 
!C  THE SUBROUTINE IS DESIGNED FOR PLANE (2D) STRESS STATES. 
!C  IT IS BASED ON THE FULLY IMPLICIT RETURN MAPPING ALGORITHM (with quadratic line search) 
!C  ONE STATE VARIABLE : HARDENING PARAMETER (THE EQUIVALENT PLASTIC STRAIN).
!C  IT IS ASSUMED THAT THE USER HAS DEFINED (USING THE *ORIENTATION OPTION IN ABAQUS)
!C  A LOCAL COORDINATE SYSTEM THAT ROTATES WITH THE MATERIAL (SO THAT DEROT IS ALWAYS
!C  EQUAL WITH THE IDENTITY MATRIX).
!C*****************************************************************************
!C The vector PROPS(NPROPS) contains the material properties as defined in the 
!C  *MATERIAL=USER option in ABAQUS in the following order
!C  PROPS(1) = EMOD  (Elasticity: Young modulus)
!C  PROPS(2) = MU  (Elasticity: Poisson ratio)
!C  Hardening laws defined: 
!C  Swift (power-)law: sigma^bar = a*(b + ep^bar)**c
!C  Voce (exp-)law: sigma^bar = a - b*exp(-c*ep^bar)  (default)
!C  Read further naming/renaming convention in the HARDENING section of this code 
!C  (more specific hardening laws can be implemented in the same section) 
!C  PROPS(3) = a 
!C  PROPS(4) = b
!C  PROPS(5) = c
!C  PROPS(6),...,PROPS(NPROPS): PARAMETERS OF YIELD FUNCTION
!C  Yield func implemented: PolyN
!C  Note: The first two parameters are the degree and number of coefficients
!C!************************************************************************************** 

!CCCC-----NOTE: the UMAT interface may vary with the ABAQUS version 	
!C	SUBROUTINE UMAT(STRESS,STATEV,DDSDDE,SSE,SPD,SCD, &
!C      RPL,DDSDDT,DRPLDE,DRPLDT, &
!C      STRAN,DSTRAN,TIME,DTIME,TEMP,DTEMP,PREDEF,DPRED,CMNAME, &
!C      NDI,NSHR,NTENS,NSTATV,PROPS,NPROPS,COORDS,DROTT,PNEWDT, &
!C      CELENT,DFGRD0,DFGRD1,NOEL,NPT,LAYER,KSPT,KSTEP,KINC)

    SUBROUTINE UMAT(STRESS,STATEV,DDSDDE,SSE,SPD,SCD, &
      RPL,DDSDDT,DRPLDE,DRPLDT, &
      STRAN,DSTRAN,TIME,DTIME,TEMP,DTEMP,PREDEF,DPRED,CMNAME, &
      NDI,NSHR,NTENS,NSTATV,PROPS,NPROPS,COORDS,DROT,PNEWDT, &
      CELENT,DFGRD0,DFGRD1,NOEL,NPT,LAYER,KSPT,JSTEP,KINC)

!CCC---NOTE: the INCLUDE directive enforces implicit casting in conflict with 'IMPLICIT NONE'
!CC          use 'IMPLICIT NONE' in the testing/implementation phase and then comment it out    	
	INCLUDE 'ABA_PARAM.INC'
!C    INTEGER, PARAMETER :: PREC =  SELECTED_REAL_KIND(15,307)
    INTEGER, PARAMETER :: PREC = 8
!C******************************************************************************
!C  VARIABLES REQUIRED BY ABAQUS (THE ARGUMENTS OF THE SUBROUTINE)
!C  FOR A DESCRIPTION OF THE LIST OF VARIABLES SEE ABAQUS MANUAL (VOL. VI)

!C    !!!CHARACTER(80)::  CMNAME
	CHARACTER*8 CMNAME
    REAL(PREC)::SSE,SPD,SCD,RPL,DRPLDT,DTIME,TEMP,DTEMP,PNEWDT,CELENT
    INTEGER::NDI,NSHR,NTENS,NSTATV,NPROPS,NOEL,NPT,LAYER,KSPT,KINC
    REAL(PREC),DIMENSION(NTENS):: STRESS,DDSDDT,DRPLDE,STRAN,DSTRAN
    REAL(PREC),DIMENSION (NTENS, NTENS) :: DDSDDE 
    REAL(PREC),DIMENSION(NSTATV) :: STATEV
    REAL(PREC),DIMENSION(NPROPS) :: PROPS
    REAL(PREC),DIMENSION(3,3) :: DFGRD0, DFGRD1, DROT
    REAL(PREC),DIMENSION(3) :: COORDS
    REAL(PREC),DIMENSION(2) :: TIME
    REAL(PREC),DIMENSION(1) :: PREDEF, DPRED
    INTEGER,DIMENSION(4)::JSTEP

		
!C    CHARACTER*80 CMNAME
!C	INTEGER::NDI,NSHR,NTENS,NSTATV,NPROPS,NOEL,NPT,LAYER,KSPT,KINC
!C	REAL(PREC)::SSE,SPD,SCD,RPL,DRPLDT,DTIME,TEMP,DTEMP,PNEWDT,CELENT
!C    REAL(PREC),DIMENSION::STRESS(NTENS),STATEV(NSTATV),DDSDDE(NTENS,NTENS), &
!C	DDSDDT(NTENS),DRPLDE(NTENS),STRAN(NTENS),DSTRAN(NTENS), &
!C	TIME(2),PREDEF(1),DPRED(1),PROPS(NPROPS), &
!C	COORDS(3),DROT(3,3),DFGRD0(3,3),DFGRD1(3,3)
!C	INTEGER,DIMENSION::JSTEP(4)	
	
!C*******************************************************************************
!C  INTERNAL VARIABLES OF THE SUBROUTINE
      
!C  VECTOR O MATERIAL PARAMETERS
    INTEGER::NKMAT
	REAL(PREC),ALLOCATABLE, DIMENSION(:)::KMATERIALF1, KMATERIALF2
    
	REAL(PREC), PARAMETER::ZERO=0.0D0
	REAL(PREC), PARAMETER::ONE=1.0D0
	REAL(PREC), PARAMETER::TWO=2.0D0
	REAL(PREC), PARAMETER::THREE=3.0D0
	REAL(PREC), PARAMETER::SIX=6.0D0
    REAL(PREC), PARAMETER::ZTOL=1.0e-10

!C  elastic constants
	REAL(PREC) :: EMOD, ENU
!C  COMPLIANCE TENSOR
	REAL(PREC),DIMENSION(NTENS,NTENS)::SCOMP

!C  HARDENING PARAMETERS
	REAL(PREC)::AA,BB,CC
!C  HARDENING VALUES
	REAL(PREC):: HF, HPF, HFS

!C  STRESS TENSOR AND ITS INCREMENTS
	REAL(PREC),DIMENSION(NTENS)::SIGMA, DSIGMA, D2SIGMA

!C  EQUIVALENT PLASTIC STRAIN AND ITS INCREMENTS
	REAL(PREC):: EPBAR, DEPBAR, D2EPBAR

!C  YIELD FUNCTION VALUE, GRADIENT AND HESSIAN
	REAL(PREC):: YF, YFS
	REAL(PREC),DIMENSION(NTENS)::GYF
	REAL(PREC),DIMENSION(NTENS,NTENS)::HYF

!C  CONVERGENCE TOLERANCES
!    REAL(PREC),PARAMETER::TOL1=1.0E-006, TOL2=1.0E-008
	REAL(PREC),PARAMETER::TOL1=1.0E-005

!C  TEMPORARY HOLDERS
	REAL(PREC)::TT, TTA, TTB, ZALPHA, F1, FZERO, TDEPBAR, EBULK3, &
        EG2, EG, EG3, ELAM
	REAL(PREC),DIMENSION(NTENS)::YVECTOR, F2, TDSIGMA
	REAL(PREC),DIMENSION(NTENS,NTENS)::XIMAT
	REAL(PREC),DIMENSION(NTENS, NTENS)::BV, IDENTITY
	REAL(PREC),DIMENSION(NTENS)::ZZ
    REAL(PREC)::VT

!C  LOOP COUNTERS
    INTEGER::K1,K2,NRK,KK,LL,MM,II,JJ

!C  NEWTON-RAPHSON MAXIMUM NUMBER OF ITERATIONS
    INTEGER,PARAMETER:: NRMAX=1000000
	
!C PolyN interface variables 
    INTEGER::DEGREE,NCOEFF,NMON	

!C*****************************************************
	EMOD = PROPS(1)
    ENU = PROPS(2)
    AA = PROPS(3)
    BB = PROPS(4)
    CC = PROPS(5)
	DEGREE = INT(PROPS(6))
	NCOEFF = INT(PROPS(7))
	NKMAT = NPROPS - 7
	
	ALLOCATE (KMATERIALF1(NKMAT - 2))
	KMATERIALF1 = PROPS(8:7+NKMAT - 2)
    ALLOCATE (KMATERIALF2(2))
    KMATERIALF2 = PROPS(7+NKMAT - 1:7 + NKMAT)

			
!C!********************************************
!C RECOVER THE EQUIVALENT PLASTIC STRAIN AT THE BEGINING OF THE INCREMENT
    EPBAR = STATEV(1)
!C**********************************************************************
!C     WRITE TO A FILE
!C**********************************************************************
      
!C!********************************************
!C INITIALIZE THE STIFFNESS TENSOR (IT WILL BE STORED IN DDSDDE)
    DDSDDE = ZERO

!C ELASTIC PROPERTIES (3D STRESS)
    EBULK3 = EMOD/(ONE - TWO*ENU)
    EG2 = EMOD/(ONE+ENU)
    EG = EG2/TWO
    EG3 = THREE*EG
    ELAM = (EBULK3 - EG2)/THREE

!C COMPUTE THE STIFFNESS TENSOR IN 3D
    
    DO K1=1, NDI
        DO K2=1, NDI
            DDSDDE(K2, K1)=ELAM
        END DO
        DDSDDE(K1, K1)=EG2+ELAM
    END DO
    DO K1=NDI+1, NTENS
        DDSDDE(K1, K1)=EG
    END DO    

    IF (1 > 1) THEN
	write(*,*)0
    END IF
    
!C COMPUTE THE TRIAL STRESS : SIGMA_{N+1} = SIGMA_{N} + C[DELTA_EPSILON]

    DO K1=1, NTENS
        TT = ZERO
        DO K2=1, NTENS
            TT = TT + DDSDDE(K1, K2) * DSTRAN(K2)
        END DO
        DSIGMA(K1)= TT
        SIGMA(K1) = STRESS(K1) + TT
    END DO
!C  write(*,*)"DS",DSTRAN
!C  write(*,*)"S",STRESS
!C  write(*,*)"SIG",SIGMA

!C      DO K1=1,NTENS,1
!C      TT=DDSDDE(K1,1)*DSTRAN(1)+DDSDDE(K1,2)*DSTRAN(2)+DDSDDE(K1,3)*DSTRAN(3)
!C      DSIGMA(K1) = TT
!C      SIGMA(K1)=STRESS(K1)+TT
!C      END DO

!C!***********************TEST ZONE*********************
    !C  write(*,*)"TEST 1", ZERO ** 2
    !C  write(*,*)"TEST 2", ZERO ** (-1)
    !C  write(*,*)"TEST 3", ZERO * ZERO ** (-1)
    !C  write(*,*)"TEST 4", ZERO * ZERO ** (-1) + ONE
    !C  write(*,*)"TEST 5", 1.0E-10 ** (-2) * ZERO


!C CHECK YIELDING CONDITION
    CALL KHARD(HF,HPF,EPBAR,AA,BB,CC)
    CALL YFUNCTION(SIGMA,NTENS,YF,KMATERIALF1, KMATERIALF2, NKMAT,DEGREE)

!C  ELASTIC STEP :  UPDATE STRESS
	IF (YF <= HF) THEN
        !C****write(80,1)TIME, EPBAR, SIGMA(1),YF, HF, AA, BB, CC
	    STRESS = SIGMA
!C  DDSDDE HAS BEEN DEFINED ABOVE
!C  THE EQUIVALENT PLASTIC STRAIN, STATEV(1), REMAINS UNCHANGED
        DEALLOCATE(KMATERIALF1)	
        DEALLOCATE(KMATERIALF2)			
        RETURN
	END IF

    !c  write(*,*)"Je passe en plastique"
    !c  IF (ISNAN(STRESS(1))) THEN
    !c    write(*,*)"Plantage"
    !c  END IF
    !c write(*,*)"STRESS", STRESS
    !c write(*,*)"SIGMA", SIGMA

!C***********************************************
!C MAIN LOOP : RETURN MAPPING ALGORITHM

!C  DEFINE COMPLIANCE (note that it outputs ENGINEERING shears)
    
    TTA=1.0D0/EMOD
	TTB=-ENU/EMOD 
    TT=TWO*(ONE+ENU)/EMOD
    SCOMP = ZERO
    DO K1=1, NDI
        DO K2=1, NDI
            SCOMP(K2, K1) = TTB
        END DO
        SCOMP(K1, K1) = TTA
    END DO
    DO K1=NDI+1, NTENS
        SCOMP(K1, K1)=TT
    END DO
!C  SCOMP CHECKED
    
	
!C  SCOMP(1,1)=TTA
!C  SCOMP(2,1)=TTB
!C  SCOMP(3,1)=ZERO
!C  SCOMP(1,2)=TTB
!C  SCOMP(2,2)=TTA
!C  SCOMP(3,2)=ZERO
!C  SCOMP(1,3)=ZERO
!C  SCOMP(2,3)=ZERO
!C  SCOMP(3,3)=2.0D0*(1.0D0+ENU)/EMOD

!C    FIRST Newton-Raphson step (no Hessian required)
!C**************************************************************      
!C  DEPBAR=ZERO

	CALL GYFUNCTION(SIGMA,NTENS,YF,GYF,KMATERIALF1, KMATERIALF2,NKMAT,DEGREE)
	F1=YF-HF



!C  ASSEMBLE XIMAT MATRIX AND Y-VECTOR
    DO K1=1,NTENS,1
	    YVECTOR(K1)=-F1*GYF(K1)
	    DO K2=K1,NTENS,1
	        TT=HPF*SCOMP(K1,K2)+GYF(K1)*GYF(K2)
	        XIMAT(K1,K2)=TT
	        XIMAT(K2,K1)=TT
	    END DO
	END DO

    !C  write(*,*)"XIMAT", XIMAT

    DO K1=1, NTENS, 1
        DO K2=1, NTENS, 1
            BV(K1,K2)=XIMAT(K1,K2)
        END DO
    END DO

!C  SOLVE FOR STRESS NR-INCREMENT USING CHOLESKY ALGORITHM
    DO JJ=1, NTENS, 1
        DO KK=1, JJ-1, 1
            BV(JJ,JJ)= BV(JJ,JJ) - BV(JJ,KK) * BV(JJ,KK)
        END DO
        BV(JJ,JJ) = DSQRT(BV(JJ,JJ))
        DO II=(JJ+1), NTENS, 1
            DO KK=1, JJ-1, 1
                BV(II,JJ)=BV(II,JJ) - BV(II,KK) * BV(JJ,KK)
            END DO
            BV(II,JJ)=BV(II,JJ)/BV(JJ,JJ)
        END DO
    END DO

    !C  write(*,*)"BV", BV
    
	DO II=1, NTENS, 1
        ZZ(II) = YVECTOR(II)
        DO JJ = 1, II-1, 1
            ZZ(II) = ZZ(II) - BV(II, JJ) * ZZ(JJ)
        END DO
        ZZ(II) = ZZ(II) / BV(II, II)
    END DO

    !C  write(*,*)"ZZ", ZZ
    
    DO II=NTENS, 1, -1
        D2SIGMA(II) = ZZ(II)
        DO JJ =II+1 , NTENS, 1
            D2SIGMA(II) = D2SIGMA(II) - BV(JJ, II) * D2SIGMA(JJ)
        END DO
        D2SIGMA(II) = D2SIGMA(II) / BV(II, II)
    END DO

    !C  write(*,*)"D2SIGMA", D2SIGMA

    

!C  CALCULATE EQUIVALENT PLASTIC STRAIN NR-INCREMENT 
    D2EPBAR=F1
	DO K1=1,NTENS,1
	    D2EPBAR=D2EPBAR+GYF(K1)*D2SIGMA(K1)
	END DO
	D2EPBAR=D2EPBAR/HPF
    
!C  DO LINE SEARCH (along the full NR-step)
    TDEPBAR=D2EPBAR
	TDSIGMA=DSIGMA+D2SIGMA	
    FZERO=F1
    CALL LSEARCH(NTENS,STRESS,TDSIGMA,DSTRAN,EPBAR,TDEPBAR,FZERO, &
	             SCOMP,KMATERIALF1, KMATERIALF2, NKMAT,AA,BB,CC,ZALPHA,DEGREE)

!C  UPDATE

    DEPBAR=ZALPHA*D2EPBAR
	DSIGMA=DSIGMA+ZALPHA*D2SIGMA

    !C  write(*,*)"YF", YF
    !C  write(*,*)"GYF", GYF
    !C  write(*,*)"HYF", HYF
	
!C    THE REST OF N-R ITERATIONS
!C******************************************************	     
    DO NRK=1,NRMAX,1

!C      CALCULATE NEW VALUES ASSOCIATED WITH NEW STATE
        CALL KHARD(HF,HPF,EPBAR+DEPBAR,AA,BB,CC)
	    SIGMA=STRESS+DSIGMA
	    CALL HYFUNCTION(SIGMA,NTENS,YF,GYF,HYF,KMATERIALF1, KMATERIALF2,NKMAT,DEGREE)
        

	    F1=YF-HF
	    FZERO=F1*F1
	    DO K1=1,NTENS,1
	          TT=DEPBAR*GYF(K1)-DSTRAN(K1)
	          DO K2=1,NTENS,1
	              TT=TT+SCOMP(K1,K2)*DSIGMA(K2)
	          END DO
	          F2(K1)=TT
	          FZERO=FZERO+TT*TT
	    END DO
        FZERO=DSQRT(FZERO)
!C      CHECK TOLERANCES
!C        IF ((DABS(F1)<TOL1).AND.(DSQRT(TTB)<TOL2)) EXIT
        !c  write(80,1)F1/TOL1  
        IF(FZERO<TOL1) EXIT

        !C  write(*,*)"ZZ PRE", NRK, ZZ
        
        !C  write(*,*)"YVECTOR PRE", NRK, XIMAT
        !C  write(*,*)"XIMAT PRE", NRK, XIMAT

!C      ASSEMBLE XIMAT MATRIX AND Y-VECTOR
        DO K1=1,NTENS,1
	        YVECTOR(K1)=-(F1*GYF(K1)+HPF*F2(K1))
	        DO K2=K1,NTENS,1
	            TT=HPF*(SCOMP(K1,K2)+DEPBAR*HYF(K1,K2))+GYF(K1)*GYF(K2)
	            XIMAT(K1,K2)=TT
                XIMAT(K2,K1)=TT
            END DO
	    END DO

        !C  write(*,*)"XIMAT", NRK, XIMAT

        DO K1=1, NTENS, 1
            DO K2=1, NTENS, 1
                BV(K1,K2)=XIMAT(K1,K2)
            END DO
        END DO

        !C  write(*,*)"BV PRE", NRK, BV
        
!C      SOLVE FOR STRESS NR-INCREMENT USING CHOLESKY ALGORITHM
        DO JJ=1, NTENS, 1
            !C  write(*,*)"JJ, NRK, BV(JJ,JJ) PRE BOUCLE", JJ, NRK, BV(JJ, JJ)
            DO KK=1, JJ-1, 1
                !C  write(*,*)"JJ,KK", JJ, KK
                BV(JJ,JJ)= BV(JJ,JJ) - BV(JJ,KK) * BV(JJ,KK)
            END DO
            !C  write(*,*)"JJ, NRK, BV(JJ,JJ) POST BOUCLE", JJ, NRK, BV(JJ, JJ)
            BV(JJ,JJ) = DSQRT(BV(JJ,JJ))
            !C  write(*,*)"JJ, NRK, BV(JJ,JJ) POST BOUCLE ET SQRT", JJ, NRK, BV(JJ, JJ)
            DO II=(JJ+1), NTENS, 1
                DO KK=1, JJ-1, 1
                    BV(II,JJ) = BV(II,JJ) - BV(II,KK) * BV(JJ,KK)
                END DO
                BV(II,JJ)=BV(II,JJ)/BV(JJ,JJ)
            END DO
        END DO
        
        !C  write(*,*)"BV POST", NRK, BV

        DO II=1, NTENS, 1
            ZZ(II) = YVECTOR(II)
            DO JJ = 1, II-1, 1
                ZZ(II) = ZZ(II) - BV(II, JJ) * ZZ(JJ)
            END DO
            ZZ(II) = ZZ(II) / BV(II, II)
        END DO
        
        !C  write(*,*)"ZZ POST", NRK, ZZ
        !C  write(*,*)"BV POST", NRK, BV
        !C  write(*,*)"YVECTOR POST", NRK, XIMAT
        !C  write(*,*)"XIMAT POST", NRK, XIMAT


        DO II=NTENS, 1, -1
            D2SIGMA(II) = ZZ(II)
            DO JJ =II+1 , NTENS, 1
                D2SIGMA(II) = D2SIGMA(II) - BV(JJ, II) * D2SIGMA(JJ)
            END DO
            D2SIGMA(II) = D2SIGMA(II) / BV(II, II)
        END DO

!C      CALCULATE EQUIVALENT PLASTIC STRAIN NR-INCREMENT 
        D2EPBAR=F1
        !C  write(*,*),"D2PBAR PRE", NRK, D2EPBAR
        !C  write(*,*)"GYF", NRK, GYF
        !C  write(*,*)"D2SIGMA POST", NRK, D2SIGMA
        !C  write(*,*)"HPF", NRK, HPF


	    DO K1=1,NTENS,1
	        D2EPBAR=D2EPBAR+GYF(K1)*D2SIGMA(K1)
	    END DO
	    D2EPBAR=D2EPBAR/HPF

!C      DO LINE SEARCH
        TDEPBAR=DEPBAR+D2EPBAR
	    TDSIGMA=DSIGMA+D2SIGMA

        !C  write(*,*),"D2PBAR POST", NRK, D2EPBAR

        CALL LSEARCH(NTENS,STRESS,TDSIGMA,DSTRAN,EPBAR,TDEPBAR,FZERO, &
	             SCOMP,KMATERIALF1, KMATERIALF2,NKMAT,AA,BB,CC,ZALPHA,DEGREE)

!C      UPDATE

        DEPBAR=DEPBAR+ZALPHA*D2EPBAR
	    DSIGMA=DSIGMA+ZALPHA*D2SIGMA
        
        !C  write(*,*),"DEPBAR", NRK, DEPBAR
        IF (NRK .GT. 10) THEN
            write(*,*)NRK
        END IF
	END DO !!! END OF NEWTON-RAPHSON ITERATIONS
        
!C  UPDATE STATE VARIABLE

    !C  write(*,*)"EPBAR, DEPBAR", EPBAR, DEPBAR
    STATEV(1)=EPBAR+DEPBAR

!C  UPDATE STRESS
    STRESS = STRESS+DSIGMA
    !C  write(*,*)"DSIGMA", DSIGMA
!C************************************** COMPUTE TANGENT MODULUS: DDSDDE

!C  COMPUTE XIMAT (M) MATRIX 
    DO K1=1,NTENS,1
	    DO K2=K1,NTENS,1
	        TT=SCOMP(K1,K2)+DEPBAR*HYF(K1,K2)
	        XIMAT(K1,K2)=TT
	        XIMAT(K2,K1)=TT
	    END DO
	END DO

    DO K1=1, NTENS, 1
        XIMAT(K1, K1) = SCOMP(K1,K1)+DEPBAR*HYF(K1,K1)
    END DO
    
    DO K1=1, NTENS, 1
        DO K2=1, NTENS, 1
            BV(K1,K2)=XIMAT(K1,K2)
        END DO
    END DO

    !C  write(*,*)"XIMAT", XIMAT
!C  INVERT XIMAT AND STORE XIMAT^(-1) INTO SCOMP (NO LONGER NEEDED)
    DO JJ=1, NTENS, 1
        DO KK=1, JJ-1, 1
            BV(JJ,JJ)= BV(JJ,JJ) - BV(JJ,KK) * BV(JJ,KK)
        END DO
        !C  write(*,*)"BV(JJ,JJ)", JJ, BV(JJ,JJ)
        BV(JJ,JJ) = DSQRT(BV(JJ,JJ))
        DO II=(JJ+1), NTENS, 1
            DO KK=1, JJ-1, 1
                BV(II,JJ)=BV(II,JJ) - BV(II,KK) * BV(JJ,KK)
            END DO
            BV(II,JJ)=BV(II,JJ)/BV(JJ,JJ)
        END DO
    END DO
    
    !C  write(*,*)"BV", BV
    IDENTITY=ZERO
    
    DO II=1, NTENS, 1
        IDENTITY(II,II)=ONE
    END DO
	
    DO LL=1, NTENS, 1
        DO II=1, NTENS, 1
            ZZ(II) = IDENTITY(II, LL)
            DO JJ = 1, II-1, 1
                ZZ(II) = ZZ(II) - BV(II, JJ) * ZZ(JJ)
            END DO
            ZZ(II) = ZZ(II) / BV(II, II)
        END DO
    
    !C  write(*,*)"ZZ", ZZ
        
        DO II=NTENS, 1, -1
            SCOMP(II, LL) = ZZ(II)
            DO JJ =II+1 , NTENS, 1
                SCOMP(II, LL) = SCOMP(II, LL) - BV(JJ, II) * SCOMP(JJ, LL)
            END DO
            SCOMP(II, LL) = SCOMP(II, LL) / BV(II, II)
        END DO
    END DO

    !C  write(*,*)"SCOMP", SCOMP
    
    SCOMP(1,2)=SCOMP(2,1)
    SCOMP(1,3)=SCOMP(3,1)
    SCOMP(1,4)=SCOMP(4,1)
    SCOMP(1,5)=SCOMP(5,1)
    SCOMP(1,6)=SCOMP(6,1)
    SCOMP(2,3)=SCOMP(3,2)
    SCOMP(2,4)=SCOMP(4,2)
    SCOMP(2,5)=SCOMP(5,2)
    SCOMP(2,6)=SCOMP(6,2)
    SCOMP(3,4)=SCOMP(4,3)
    SCOMP(3,5)=SCOMP(5,3)
    SCOMP(3,6)=SCOMP(6,3)
    SCOMP(4,5)=SCOMP(5,4)
    SCOMP(4,6)=SCOMP(6,4)
    SCOMP(5,6)=SCOMP(6,5)
	
	
!C  CALCULATE  SCOMP[GYF] AND STORE IT INTO DSIGMA
!C  DSIGMA=(/ZERO,ZERO,ZERO/)

	DSIGMA=ZERO
    DO K1=1,NTENS,1
	    DO K2=1,NTENS,1
	        DSIGMA(K2)=DSIGMA(K2)+SCOMP(K2,K1)*GYF(K1)
	    END DO
	END DO

!C  CALCULATE 1/K
    TT=HPF
	DO K1=1,NTENS,1
	    TT=TT+GYF(K1)*DSIGMA(K1)
	END DO

!C  UPDATE DDSDDE
    DO K1=1,NTENS,1
	    DO K2=K1,NTENS,1
	        TTB=SCOMP(K1,K2)-DSIGMA(K1)*DSIGMA(K2)/TT
	        DDSDDE(K1,K2)=TTB
            DDSDDE(K2,K1)=TTB
	    END DO
	END DO
    
    !C  write(*,*)"SCOMP", SCOMP
    !C  write(*,*)"DSIGMA", DSIGMA
	DO K1=1,NTENS,1
	    DDSDDE(K1,K1)=SCOMP(K1,K1)-DSIGMA(K1)*DSIGMA(K1)/TT
	END DO

    
    !C  write(*,*)"DDSDDE", DDSDDE
    DEALLOCATE(KMATERIALF1)
    DEALLOCATE(KMATERIALF2)
    RETURN
    END SUBROUTINE UMAT


!C**************************HARDENING***************************
!C*****NOTE:
!C*****THIS UMAT IDENTIFIES THE HARDENING SUB BY THE NAME 'KHARD'
!C*****(DEACTIVATE THE OTHER BY RENAMING)
     	
!C****: Swift (Power hardening law)
    SUBROUTINE   KHARD(HF,HPF,EPBAR,AAZ,BBZ,CCZ)
!C      COMPUTES THE HARDENING AND ITS DERIVATIVE
    
    IMPLICIT NONE
    INTEGER, PARAMETER :: PREC = 8
    REAL(PREC) :: HF, HPF, EPBAR, AAZ, BBZ, CCZ
    HF  = AAZ*((BBZ+EPBAR)**CCZ)
    HPF =  (CCZ/(BBZ+EPBAR))*HF
    RETURN
    END SUBROUTINE  KHARD

!C****: Voce (Exponential hardening law)
    SUBROUTINE  swKHARD(HF,HPF,EPBAR,AAZ,BBZ,CCZ)
!C      COMPUTES THE HARDENING AND ITS DERIVATIVE
    
    IMPLICIT NONE
    INTEGER, PARAMETER :: PREC = 8
    REAL(PREC) :: HF, HPF, EPBAR, AAZ, BBZ, CCZ, ONE
    ONE = 1.0D0
    HF= BBZ * (ONE - EXP(-CCZ*EPBAR))
	HPF = -CCZ * BBZ * EXP(-CCZ * EPBAR)
    HF  = AAZ-HF
    RETURN
    END SUBROUTINE  swKHARD

!C**********************************************************
	SUBROUTINE LSEARCH(NTENS,STRESS,TDSIGMA,DSTRAN,EPBAR,TDEPBAR,FZERO, &
	                   SCOMP,KMATERIALF1, KMATERIALF2,NKMAT,AAZ,BBZ,CCZ,ZALPHA,DEGREE) 

	IMPLICIT NONE
	INTEGER,PARAMETER::PREC=8

    INTEGER::NTENS, NKMAT,DEGREE
	REAL(PREC),DIMENSION(NTENS)::STRESS,TDSIGMA,DSTRAN
	REAL(PREC),DIMENSION(NTENS,NTENS)::SCOMP
	REAL(PREC)::EPBAR,TDEPBAR,FZERO,AAZ,BBZ,CCZ,ZALPHA
	REAL(PREC),DIMENSION(NKMAT - 2)::KMATERIALF1
    REAL(PREC),DIMENSION(2)::KMATERIALF2

!C     INTERNAL VARIABLES
    REAL(PREC),DIMENSION(NTENS)::TSIGMA,GYF  
	REAL(PREC)::HF,HPF,TEPBAR,YF,TT,FONE
	INTEGER::KK,JJ

    TSIGMA=STRESS+TDSIGMA
	TEPBAR=EPBAR+TDEPBAR
	
	CALL KHARD(HF,HPF,TEPBAR,AAZ,BBZ,CCZ)
	CALL GYFUNCTION(TSIGMA,NTENS,YF,GYF,KMATERIALF1,KMATERIALF2,NKMAT,DEGREE)
	
    FONE=(YF-HF)
	FONE=FONE*FONE
	DO KK=1,NTENS,1
	    TT=TDEPBAR*GYF(KK)-DSTRAN(KK)
	    DO JJ=1,NTENS,1
	        TT=TT+SCOMP(KK,JJ)*TDSIGMA(JJ)
	    END DO
	FONE=FONE+TT*TT
	END DO
	FONE=DSQRT(FONE)
	ZALPHA=1.0D0
	IF(FONE<=0.5D0*FZERO) RETURN	
	
!!	ZALPHA=0.75D0*(FZERO/(2.0D0*FONE))
    ZALPHA=0.375D0*(FZERO/FONE)	
    RETURN
    END SUBROUTINE LSEARCH	
!C*********************************************************************************

!CCCCCCC********** YIELD FUNCTION CALCULATIONS ***********************************
!CCCCCCC NOTE:   YFUNCTION RETURNS JUST YIELD FUNCTION VALUE
!CCCCCCC        GYFUNCTION RETURNS YIELD FUNCTION VALUE AND GRADIENT
!CCCCCCC        HYFUNCTION RETURNS YIELD FUNCTION VALUE, GRADIENT AND HESSIAN
!C
!CCCCCC************** PolyN YIELD FUNCTION: 
!CCCCCC************** 1) ORTHOTROPIC SYMMETRY 
!CCCCCC************** 2) HOMOGENEITY DEGREE = N (any degree)

    SUBROUTINE POLY2D(TLIN, P, KMATERIALF1, NKMAT, DEGREE)
    IMPLICIT NONE
    INTEGER, PARAMETER::PREC=8

    INTEGER::NKMAT,DEGREE
    REAL(PREC),DIMENSION(3)::TLIN
	REAL(PREC),DIMENSION(NKMAT - 2)::KMATERIALF1
	REAL(PREC)::P
	INTEGER::II,JJ,KK,N0

    REAL(PREC), PARAMETER::ZERO=0.0D0

    P = ZERO

    N0 = 1
    DO KK=0, DEGREE, 1
        DO JJ=0, DEGREE - KK, 1
            II = DEGREE - KK - JJ
            IF (MOD(KK,2)==0) THEN
                P = P + KMATERIALF1(N0) &
                * TLIN(1) ** DBLE(II) &
                * TLIN(2) ** DBLE(JJ) &
                * TLIN(3) ** DBLE(KK)
                N0 = N0 + 1
            END IF
        END DO
    END DO

	RETURN
    END SUBROUTINE POLY2D

    SUBROUTINE GRADPOLY2D(TLIN, GRADP, KMATERIALF1, NKMAT, DEGREE)
    IMPLICIT NONE
    INTEGER, PARAMETER::PREC=8

    INTEGER::NKMAT,DEGREE
    REAL(PREC),DIMENSION(3)::TLIN
    REAL(PREC),DIMENSION(3)::GRADP
	REAL(PREC),DIMENSION(NKMAT - 2)::KMATERIALF1
	INTEGER::II,JJ,KK,N0

    REAL(PREC), PARAMETER::ZERO=0.0D0

    N0 = 1
    GRADP = ZERO

    DO KK=0, DEGREE, 1
        DO JJ=0, DEGREE - KK, 1
            II=DEGREE - KK - JJ
            IF (MOD(KK,2)==0) THEN
                IF (II > 0) THEN
                    GRADP(1) = GRADP(1) + KMATERIALF1(N0) &
                        * DBLE(II) * TLIN(1) ** (DBLE(II-1)) &
                        * TLIN(2) ** DBLE(JJ) &
                        * TLIN(3) ** DBLE(KK)
                END IF
                IF (JJ > 0) THEN
                    GRADP(2) = GRADP(2) + KMATERIALF1(N0) &
                        * TLIN(1) ** DBLE(II) &
                        * DBLE(JJ) * TLIN(2) ** (DBLE(JJ-1)) &
                        * TLIN(3) ** DBLE(KK) 
                END IF
                IF (KK > 0) THEN
                    GRADP(3) = GRADP(3) + KMATERIALF1(N0) &
                        * TLIN(1) ** DBLE(II) &
                        * TLIN(2) ** DBLE(JJ) &
                        * DBLE(KK) * TLIN(3) ** (DBLE(KK-1))
                END IF
                N0 = N0 + 1
            END IF
        END DO
    END DO

    RETURN

    END SUBROUTINE GRADPOLY2D

    SUBROUTINE HESSPOLY2D(TLIN, HESSP, KMATERIALF1, NKMAT, DEGREE)
    IMPLICIT NONE
    INTEGER, PARAMETER::PREC=8

    INTEGER::NKMAT,DEGREE
    REAL(PREC),DIMENSION(3)::TLIN
    REAL(PREC),DIMENSION(3, 3)::HESSP
	REAL(PREC),DIMENSION(NKMAT - 2)::KMATERIALF1
	INTEGER::II,JJ,KK,N0

    REAL(PREC), PARAMETER::ZERO=0.0D0

    HESSP = ZERO
    N0 = 1

    DO KK=0, DEGREE, 1
        DO JJ=0, DEGREE - KK, 1
            II = DEGREE - KK - JJ
            IF (MOD(KK,2)==0) THEN
                
                IF (II > 0) THEN
                    IF (II > 1) THEN
                        HESSP(1,1) = HESSP(1,1) + KMATERIALF1(N0) &
                            * DBLE(II) * (DBLE(II-1)) * TLIN(1) ** (DBLE(II-2)) &
                            * TLIN(2) ** DBLE(JJ) &
                            * TLIN(3) ** DBLE(KK)
                    END IF
                    IF (JJ > 0) THEN
                        HESSP(1,2) = HESSP(1,2) + KMATERIALF1(N0) &
                            * DBLE(II) * TLIN(1) ** (DBLE(II-1)) &
                            * DBLE(JJ) * TLIN(2) ** (DBLE(JJ-1)) &
                            * TLIN(3) ** DBLE(KK)
                    END IF
                    IF (KK > 0) THEN
                        HESSP(1,3) = HESSP(1,3) + KMATERIALF1(N0) &
                            * DBLE(II) * TLIN(1) ** (DBLE(II-1)) &
                            * TLIN(2) ** DBLE(JJ) &
                            * DBLE(KK) * TLIN(3) ** (DBLE(KK - 1))
                    END IF
                END IF

                IF (JJ > 0) THEN
                    IF (JJ > 1) THEN
                        HESSP(2,2) = HESSP(2,2) + KMATERIALF1(N0) &
                            * TLIN(1) ** DBLE(II) &
                            * DBLE(JJ) * (DBLE(JJ-1)) * TLIN(2) ** (DBLE(JJ - 2)) &
                            * TLIN(3) ** DBLE(KK)
                    END IF
                    IF (KK > 0) THEN
                        HESSP(2,3) = HESSP(2,3) + KMATERIALF1(N0) &
                            * TLIN(1) ** DBLE(II) &
                            * DBLE(JJ) * TLIN(2) ** (DBLE(JJ - 1)) &
                            * DBLE(KK) * TLIN(3) ** (DBLE(KK - 1))
                    END IF
                END IF
                
                
                IF (KK > 1) THEN
                    HESSP(3,3) = HESSP(3,3) + KMATERIALF1(N0) &
                        * TLIN(1) ** DBLE(II) &
                        * TLIN(2) ** DBLE(JJ) &
                        * DBLE(KK) * (DBLE(KK - 1)) * TLIN(3) ** (DBLE(KK - 2))
                END IF
                N0 = N0 + 1
            END IF
        END DO
    END DO

    HESSP(2,1) = HESSP(1,2)
    HESSP(3,1) = HESSP(1,3)
    HESSP(3,2) = HESSP(2,3)

    RETURN

    END SUBROUTINE HESSPOLY2D

    SUBROUTINE YFUNCTION(SIGMA,NTENS, YF,KMATERIALF1,KMATERIALF2,NKMAT,DEGREE)
    IMPLICIT NONE
	INTEGER,PARAMETER::PREC=8

    INTEGER::NTENS, NKMAT,DEGREE
	REAL(PREC),DIMENSION(NTENS)::SIGMA
	REAL(PREC),DIMENSION(3)::TLIN
	REAL(PREC),DIMENSION(NKMAT - 2)::KMATERIALF1
    REAL(PREC),DIMENSION(2)::KMATERIALF2
	REAL(PREC)::YF, FF1, FF2, ONEHALF, P, G
    REAL(PREC), PARAMETER::ZERO=0.0D0
    REAL(PREC), PARAMETER::ONE=1.0D0
    REAL(PREC), PARAMETER::TWO=2.0D0

    ONEHALF = ONE/TWO
	YF = ZERO
    FF1 = ZERO
    FF2 = ZERO
    G = ZERO
	P = ZERO
    TLIN = ZERO

    TLIN(1) = SIGMA(1) - SIGMA(3)
    TLIN(2) = SIGMA(2) - SIGMA(3)
    TLIN(3) = SIGMA(4)

    CALL POLY2D(TLIN, P, KMATERIALF1, NKMAT, DEGREE)
    
    FF1 = P**(TWO/DBLE(DEGREE))
    FF2 = KMATERIALF2(1) * SIGMA(5) ** 2 + KMATERIALF2(2) * SIGMA(6) ** 2

    G = FF1 + FF2
    YF = G ** ONEHALF

	RETURN
	END SUBROUTINE YFUNCTION

    SUBROUTINE GYFUNCTION(SIGMA,NTENS,YF,GYF,KMATERIALF1, KMATERIALF2,NKMAT,DEGREE)
    IMPLICIT NONE
	INTEGER,PARAMETER::PREC=8

    INTEGER::NTENS, NKMAT,DEGREE
	REAL(PREC),DIMENSION(NTENS)::SIGMA, GYF
	REAL(PREC),DIMENSION(3)::GRADP
	REAL(PREC),DIMENSION(NTENS)::GRADF1, GRADF2, GRADG
    REAL(PREC),DIMENSION(3)::TLIN
	REAL(PREC),DIMENSION(3, NTENS)::GRADTLIN   
	REAL(PREC),DIMENSION(NKMAT - 2)::KMATERIALF1
    REAL(PREC),DIMENSION(2)::KMATERIALF2
	REAL(PREC)::YF,ZYF,P, FF1, FF2, ONEHALF, G
    
    REAL(PREC), PARAMETER::ZERO=0.0D0
    REAL(PREC), PARAMETER::ONE=1.0D0
    REAL(PREC), PARAMETER::TWO=2.0D0

    INTEGER::II, JJ, KK

    ONEHALF = ONE/TWO

	YF = ZERO
	GYF = ZERO
    GRADF1 = ZERO
    GRADF2 = ZERO
    GRADG = ZERO
	P = ZERO
    G = ZERO
    FF1 = ZERO
    FF2 = ZERO
    TLIN = ZERO

    TLIN(1) = SIGMA(1) - SIGMA(3)
    TLIN(2) = SIGMA(2) - SIGMA(3)
    TLIN(3) = SIGMA(4)

    GRADTLIN = ZERO
	GRADTLIN(1,1) = ONE
	GRADTLIN(1,3) = - ONE
	GRADTLIN(2,2) = ONE
	GRADTLIN(2,3) = - ONE
	GRADTLIN(3,4) = ONE
	
    CALL POLY2D(TLIN, P, KMATERIALF1, NKMAT, DEGREE)
    CALL GRADPOLY2D(TLIN, GRADP, KMATERIALF1, NKMAT, DEGREE)

    FF1 = P**(TWO/DBLE(DEGREE))
    FF2 = KMATERIALF2(1) * SIGMA(5) ** 2 + KMATERIALF2(2) * SIGMA(6) ** 2

    G = FF1 + FF2
    YF = G ** ONEHALF

    DO II=1, NTENS, 1
        DO JJ = 1, 3, 1
            GRADF1(II) = GRADF1(II) + GRADTLIN(JJ, II) * GRADP(JJ)
        END DO
    END DO

    GRADF1 = (TWO/DBLE(DEGREE)) * GRADF1 * P ** (TWO/DBLE(DEGREE) - ONE) 
    
    GRADF2(5) = 2 * KMATERIALF2(1) * SIGMA(5)
    GRADF2(6) = 2 * KMATERIALF2(2) * SIGMA(6)

    GRADG = GRADF1 + GRADF2
    
    GYF = ONEHALF * GRADG / (G**ONEHALF)
	RETURN
    
	END SUBROUTINE GYFUNCTION
!CC***************************************************************************

    SUBROUTINE HYFUNCTION(SIGMA, NTENS, YF, GYF, HYF, KMATERIALF1, KMATERIALF2, NKMAT, DEGREE)
    IMPLICIT NONE
	INTEGER,PARAMETER::PREC=8

    INTEGER::NTENS, NKMAT,DEGREE
	REAL(PREC),DIMENSION(NTENS)::SIGMA, GYF
    REAL(PREC),DIMENSION(NTENS, NTENS)::HYF
	REAL(PREC),DIMENSION(3)::GRADP
	REAL(PREC),DIMENSION(3, 3)::HESSP
	REAL(PREC),DIMENSION(NTENS)::GRADF1, GRADF2, GRADG
	REAL(PREC),DIMENSION(NTENS, NTENS)::HESSF1, HESSF2, HESSG, HESSF1TEMP
    REAL(PREC),DIMENSION(3)::TLIN
	REAL(PREC),DIMENSION(3, NTENS)::GRADTLIN   
	REAL(PREC),DIMENSION(NKMAT - 2)::KMATERIALF1
    REAL(PREC),DIMENSION(2)::KMATERIALF2
	REAL(PREC)::YF, FF1, FF2, P, G, ONEHALF, THREEHALF, ONEFOURTH
    
    REAL(PREC), PARAMETER::ZERO=0.0D0
    REAL(PREC), PARAMETER::ONE=1.0D0
    REAL(PREC), PARAMETER::TWO=2.0D0
    REAL(PREC), PARAMETER::THREE=3.0D0
    REAL(PREC), PARAMETER::FOUR=4.0D0

    INTEGER::II, JJ, KK, LL

    ONEHALF = ONE/TWO
    THREEHALF = THREE/TWO
    ONEFOURTH = ONE/FOUR

	YF = ZERO
    P = ZERO
    G = ZERO
	GYF = ZERO
    GRADF1 = ZERO
    GRADF2 = ZERO
    GRADG = ZERO
    GRADP = ZERO
    HESSF1 = ZERO
    HESSF2 = ZERO
    HESSG = ZERO
    HESSP = ZERO
    HESSF1TEMP = ZERO
    FF1 = ZERO
    FF2 = ZERO
    
    TLIN = ZERO

    TLIN(1) = SIGMA(1) - SIGMA(3)
    TLIN(2) = SIGMA(2) - SIGMA(3)
    TLIN(3) = SIGMA(4)

    GRADTLIN = ZERO
	GRADTLIN(1,1) = ONE
	GRADTLIN(1,3) = - ONE
	GRADTLIN(2,2) = ONE
	GRADTLIN(2,3) = - ONE
	GRADTLIN(3,4) = ONE
	
    CALL POLY2D(TLIN, P, KMATERIALF1, NKMAT, DEGREE)
    CALL GRADPOLY2D(TLIN, GRADP, KMATERIALF1, NKMAT, DEGREE)
    CALL HESSPOLY2D(TLIN, HESSP, KMATERIALF1, NKMAT, DEGREE)

    FF1 = P**(TWO/DBLE(DEGREE))
    FF2 = KMATERIALF2(1) * SIGMA(5) ** 2 + KMATERIALF2(2) * SIGMA(6) ** 2
    G = FF1 + FF2

    DO II=1, NTENS, 1
        DO JJ = 1, 3, 1
            GRADF1(II) = GRADF1(II) + GRADTLIN(JJ, II) * GRADP(JJ)
        END DO
    END DO

    GRADF1 = (TWO/DBLE(DEGREE)) * P ** (TWO/DBLE(DEGREE) - ONE) * GRADF1

    GRADF2(5) = 2 * KMATERIALF2(1) * SIGMA(5)
    GRADF2(6) = 2 * KMATERIALF2(2) * SIGMA(6)
    GRADG = GRADF1 + GRADF2

    DO II = 1, 3, 1
        DO JJ = 1, 3, 1
            HESSF1TEMP(II, JJ) = GRADP(II) * GRADP(JJ)
        END DO
    END DO

    HESSF1TEMP = (TWO/DBLE(DEGREE)) * (TWO/DBLE(DEGREE) - ONE) * P ** (TWO/DBLE(DEGREE) - TWO) * HESSF1TEMP
    HESSF1TEMP = HESSF1TEMP + (TWO/DBLE(DEGREE)) * HESSP * P ** (TWO/DBLE(DEGREE) - ONE)

	DO II=1, NTENS
		DO JJ = 1, NTENS
			DO KK = 1, 3
				DO LL = 1, 3
					HESSF1(II, JJ) = HESSF1(II, JJ) + GRADTLIN(LL, II) * HESSF1TEMP(LL, KK) * GRADTLIN(KK, JJ)
				END DO
			END DO
		END DO
	END DO

    HESSF2(5,5) = 2 * KMATERIALF2(1)
    HESSF2(6,6) = 2 * KMATERIALF2(2)

    HESSG = HESSF1 + HESSF2

    DO II = 1, NTENS, 1
        DO JJ = 1, NTENS, 1
            HYF(II, JJ) = GRADG(II) * GRADG(JJ)
        END DO
    END DO

    YF = G**ONEHALF
    GYF = ONEHALF * GRADG / YF
    HYF = (- ONEFOURTH / (G**THREEHALF))  * HYF + (ONEHALF /(G**ONEHALF)) * HESSG


	RETURN
    
	END SUBROUTINE HYFUNCTION

!CC**************************** END OF PolyN IMPLEMENTATION