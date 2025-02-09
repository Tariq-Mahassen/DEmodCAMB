module DarkEnergyInterface
    use precision
    use interpolation
    use classes
    implicit none

    private

    type, extends(TCambComponent) :: TDarkEnergyModel
        logical :: is_cosmological_constant = .true.
        integer :: num_perturb_equations = 0
    contains
    procedure :: Init
    procedure :: BackgroundDensityAndPressure
    procedure :: PerturbedStressEnergy !Get density perturbation and heat flux for sources
    procedure :: diff_rhopi_Add_Term
    procedure :: PerturbationInitial
    procedure :: PerturbationEvolve
    procedure :: PrintFeedback
    ! do not have to implement w_de or grho_de if BackgroundDensityAndPressure is inherited directly
    procedure :: w_de
    procedure :: grho_de
    procedure :: Effective_w_wa !Used as approximate values for non-linear corrections
    !procedure :: TrapezoidalIntegration
    end type TDarkEnergyModel

    type, extends(TDarkEnergyModel) :: TDarkEnergyEqnOfState
        !Type supporting w, wa or general w(z) table
        real(dl) :: w_lam = -1_dl !p/rho for the dark energy (an effective value, used e.g. for halofit), cosmological constant today
        real(dl) :: wa = 0._dl !may not be used, just for compatibility with e.g. halofit
        real(dl) :: cs2_lam = 1_dl !rest-frame sound speed, though may not be used
	real(dl) :: SteepnessDE = 0.5_dl !steepness of the transition
	real(dl) :: atrans = 0.5_dl !value of scale factor at transition
	real(dl) :: w_m = -1_dl !equation of state of dark matter
        logical :: use_tabulated_w = .false.  !Use interpolated table; note this is quite slow.
        logical :: no_perturbations = .false. !Don't change this, no perturbations is unphysical
        !Interpolations if use_tabulated_w=.true.
        Type(TCubicSpline) :: equation_of_state, logdensity
    contains
    procedure :: ReadParams => TDarkEnergyEqnOfState_ReadParams
    procedure :: Init => TDarkEnergyEqnOfState_Init
    procedure :: SetwTable => TDarkEnergyEqnOfState_SetwTable
    procedure :: PrintFeedback => TDarkEnergyEqnOfState_PrintFeedback
    procedure :: w_de => TDarkEnergyEqnOfState_w_de
    procedure :: grho_de => TDarkEnergyEqnOfState_grho_de
    procedure :: Effective_w_wa => TDarkEnergyEqnOfState_Effective_w_wa
    !procedure :: TrapezoidalIntegration => TDarkEnergyEqnOfState_TrapezoidalIntegration
    end type TDarkEnergyEqnOfState

    public TDarkEnergyModel, TDarkEnergyEqnOfState
    contains

    function w_de(this, a)
    class(TDarkEnergyModel) :: this
    real(dl) :: w_de, al
    real(dl), intent(IN) :: a

    w_de = -1._dl

    end function w_de  ! equation of state of the PPF DE

    function grho_de(this, a)  !relative density (8 pi G a^4 rho_de /grhov)
    class(TDarkEnergyModel) :: this
    real(dl) :: grho_de, al, fint
    real(dl), intent(IN) :: a

    grho_de =0._dl

    end function grho_de

    !function TrapezoidalIntegration(this, intl, khalas, numbers) result(resultValue)
    !class(TDarkEnergyModel), intent(inout) :: this
    !real(dl), INTENT(IN) :: intl, khalas
    !real(dl), INTENT(IN) :: numbers
    !real(dl) :: resultValue

    !real(dl):: stepsize, x
    !INTEGER:: i
 
    ! Step size
    !stepsize = (khalas - intl) / numbers

    ! Initialize result
    !resultValue = (f(intl) + f(khalas))*0.5d0

    ! Trapezoidal rule summation
    !DO i = 1, INT(numbers) - 1
     !x = intl + REAL(i) * stepsize
     !resultValue = resultValue + f(x)
    !END DO

    ! Multiply by step size to get the final result
    !resultValue = resultValue * stepsize
 
    !contains
    !function f(x_prime)
    !real(dl), INTENT(IN) :: x_prime
    !real(dl) :: f
    !f = x_prime
    !end function f
 
    !end function TrapezoidalIntegration

    subroutine PrintFeedback(this, FeedbackLevel)
    class(TDarkEnergyModel) :: this
    integer, intent(in) :: FeedbackLevel

    end subroutine PrintFeedback


    subroutine Init(this, State)
    use classes
    class(TDarkEnergyModel), intent(inout) :: this
    class(TCAMBdata), intent(in), target :: State

    end subroutine Init

    subroutine BackgroundDensityAndPressure(this, grhov, a, grhov_t, w)
    !Get grhov_t = 8*pi*rho_de*a**2 and (optionally) equation of state at scale factor a
    class(TDarkEnergyModel), intent(inout) :: this
    real(dl), intent(in) :: grhov, a
    real(dl), intent(out) :: grhov_t
    real(dl), optional, intent(out) :: w

    if (this%is_cosmological_constant) then
        grhov_t = grhov * a * a
        if (present(w)) w = -1_dl
    else
        ! Ensure a valid result
        if (a > 1e-10) then
            grhov_t = grhov * this%grho_de(a) / (a * a)
        else
            grhov_t = 0._dl
        end if
        if (present(w)) w = this%w_de(a)
    end if

    end subroutine BackgroundDensityAndPressure

    subroutine Effective_w_wa(this, w, wa)
    class(TDarkEnergyModel), intent(inout) :: this
    real(dl), intent(out) :: w, wa

    w = -1
    wa = 0

    end subroutine Effective_w_wa


    subroutine PerturbedStressEnergy(this, dgrhoe, dgqe, &
        a, dgq, dgrho, grho, grhov_t, w, gpres_noDE, etak, adotoa, k, kf1, ay, ayprime, w_ix)
    class(TDarkEnergyModel), intent(inout) :: this
    real(dl), intent(out) :: dgrhoe, dgqe
    real(dl), intent(in) ::  a, dgq, dgrho, grho, grhov_t, w, gpres_noDE, etak, adotoa, k, kf1
    real(dl), intent(in) :: ay(*)
    real(dl), intent(inout) :: ayprime(*)
    integer, intent(in) :: w_ix

    dgrhoe=0
    dgqe=0

    end subroutine PerturbedStressEnergy


    function diff_rhopi_Add_Term(this, dgrhoe, dgqe,grho, gpres, w, grhok, adotoa, &
        Kf1, k, grhov_t, z, k2, yprime, y, w_ix) result(ppiedot)
    class(TDarkEnergyModel), intent(in) :: this
    real(dl), intent(in) :: dgrhoe, dgqe, grho, gpres, grhok, w, adotoa, &
        k, grhov_t, z, k2, yprime(:), y(:), Kf1
    integer, intent(in) :: w_ix
    real(dl) :: ppiedot

    ! Ensure, that the result is set, when the function is not implemented by
    ! subclasses
    ppiedot = 0._dl

    end function diff_rhopi_Add_Term

    subroutine PerturbationEvolve(this, ayprime, w, w_ix, a, adotoa, k, z, y)
    class(TDarkEnergyModel), intent(in) :: this
    real(dl), intent(inout) :: ayprime(:)
    real(dl), intent(in) :: a,adotoa, k, z, y(:), w
    integer, intent(in) :: w_ix
    end subroutine PerturbationEvolve

    subroutine PerturbationInitial(this, y, a, tau, k)
    class(TDarkEnergyModel), intent(in) :: this
    real(dl), intent(out) :: y(:)
    real(dl), intent(in) :: a, tau, k
    !Get intinitial values for perturbations at a (or tau)
    !For standard adiabatic perturbations can usually just set to zero to good accuracy

    y = 0

    end subroutine PerturbationInitial


    subroutine TDarkEnergyEqnOfState_SetwTable(this, a, w, n)
    class(TDarkEnergyEqnOfState) :: this
    integer, intent(in) :: n
    real(dl), intent(in) :: a(n), w(n)
    real(dl), allocatable :: integral(:)

    if (abs(a(size(a)) -1) > 1e-5) error stop 'w table must end at a=1'

    this%use_tabulated_w = .true.
    call this%equation_of_state%Init(log(a), w)

    allocate(integral(this%equation_of_state%n))
    ! log (rho) =  -3 int dlna (1+w)
    call this%equation_of_state%IntegralArray(integral)
    integral  = -3*( (this%equation_of_state%X-this%equation_of_state%X(1)) + integral) + 4*this%equation_of_state%X
    integral = integral - integral(this%equation_of_state%n) !log(a^4 rho_de)) normalized to 0 at a=1
    call this%logdensity%Init(this%equation_of_state%X, integral)
    !Set w and wa to values today (e.g. as too simple first guess for approx fittings etc).
    this%w_lam = w(size(a))
    this%wa = -this%equation_of_state%Derivative(0._dl)

    end subroutine TDarkEnergyEqnOfState_SetwTable

    function TDarkEnergyEqnOfState_w_de(this, a)
    	class(TDarkEnergyEqnOfState) :: this
    	real(dl) :: TDarkEnergyEqnOfState_w_de, al
    	real(dl), intent(IN) :: a


    if(.not. this%use_tabulated_w) then
	TDarkEnergyEqnOfState_w_de= this%w_lam + (this%w_m - this%w_lam)*(((1-EXP(-(a-1)/this%SteepnessDE))/&
    (1-EXP(1/this%SteepnessDE)))*((1+EXP(this%atrans/this%SteepnessDE))/&
    (1+EXP(-(a-this%atrans)/this%SteepnessDE))))
    
    else
        al=dlog(a)
        if(al <= this%equation_of_state%Xmin_interp) then
            TDarkEnergyEqnOfState_w_de= this%equation_of_state%F(1)
        elseif(al >= this%equation_of_state%Xmax_interp) then
            TDarkEnergyEqnOfState_w_de= this%equation_of_state%F(this%equation_of_state%n)
        else
            TDarkEnergyEqnOfState_w_de = this%equation_of_state%Value(al)
        endif
    endif

    end function TDarkEnergyEqnOfState_w_de  ! equation of state of the PPF DE


    subroutine TDarkEnergyEqnOfState_Effective_w_wa(this, w, wa)
    class(TDarkEnergyEqnOfState), intent(inout) :: this
    real(dl), intent(out) :: w, wa

    w = this%w_lam
    wa = this%wa

    end subroutine TDarkEnergyEqnOfState_Effective_w_wa

    !function TDarkEnergyEqnOfState_TrapezoidalIntegration(this, intl, khalas, numbers) result(resultValue)
    !class(TDarkEnergyEqnOfState), intent(inout) :: this
    !real(dl), INTENT(IN) :: intl, khalas
    !real(dl), INTENT(IN) :: numbers 
    !real(dl) :: resultValue

    !real(dl):: stepsize, x
    !INTEGER :: i


    ! Step size
    !stepsize = (khalas - intl) / numbers

    ! Initialize result
    !resultValue = (integrable_function(intl) + integrable_function(khalas))*0.5d0

    ! Trapezoidal rule summation
    !DO i = 1, INT(numbers) - 1
     !x = intl + REAL(i) * stepsize
     !resultValue = resultValue + integrable_function(x)
    !END DO

    ! Multiply by step size to get the final result
    !resultValue = resultValue * stepsize
    
    !contains
	 !Integrating Dark Energy Function
     !real(dl) function integrable_function(a_prime)
     !class(TDarkEnergyEqnOfState) :: this
     !real(dl), intent(in) :: a_prime
     !integrable_function = (((1-EXP(-(a_prime-1)/this%SteepnessDE))/&
     !(1-EXP(1/this%SteepnessDE)))*((1+EXP(this%atrans/this%SteepnessDE))/&
     !(1+EXP(-(a_prime-this%atrans)/this%SteepnessDE)))) / a_prime
     !end function integrable_function

    !end function TDarkEnergyEqnOfState_TrapezoidalIntegration

    function TDarkEnergyEqnOfState_grho_de(this, a) result(grho_de) !relative density (8 pi G a^4 rho_de /grhov)
    class(TDarkEnergyEqnOfState) :: this
    real(dl) :: grho_de, al, fint
    real(dl), intent(IN) :: a

    if(.not. this%use_tabulated_w) then
        grho_de = a ** (1._dl - 3. * this%w_lam)
        if (this%wa/=0) grho_de=grho_de*exp(-3. * (this%w_m - this%w_lam) * (((1-EXP(-(a-1)/this%SteepnessDE))/&
        (1-EXP(1/this%SteepnessDE)))*((1+EXP(this%atrans/this%SteepnessDE))/&
        (1+EXP(-(a-this%atrans)/this%SteepnessDE)))) / a)
    else
        if(a == 0.d0)then
            grho_de = 0.d0      !assume rho_de*a^4-->0, when a-->0, OK if w_de always <0.
        else
            if (a>=1) then
                fint= 1
            else
                al = dlog(a)
                if(al <= this%logdensity%X(1)) then
                    ! assume here w=w_de(a_min)
                    fint = exp(this%logdensity%F(1) + (1. - 3. * this%equation_of_state%F(1))*(al - this%logdensity%X(1)))
                else
                    fint = exp(this%logdensity%Value(al))
                endif
            end if
            grho_de = fint
        endif
    endif

    end function TDarkEnergyEqnOfState_grho_de

    subroutine TDarkEnergyEqnOfState_PrintFeedback(this, FeedbackLevel)
    class(TDarkEnergyEqnOfState) :: this
    integer, intent(in) :: FeedbackLevel

    if (FeedbackLevel >0) write(*,'("(w0, wa) = (", f8.5,", ", f8.5, ")")') &
        &   this%w_lam, this%wa

    end subroutine TDarkEnergyEqnOfState_PrintFeedback

    subroutine TDarkEnergyEqnOfState_ReadParams(this, Ini)
    use IniObjects
    use FileUtils
    class(TDarkEnergyEqnOfState) :: this
    class(TIniFile), intent(in) :: Ini
    real(dl), allocatable :: table(:,:)

    this%use_tabulated_w = Ini%Read_Logical('use_tabulated_w', .false.)
    if(.not. this%use_tabulated_w)then
        this%w_lam = Ini%Read_Double('w', -1.d0)
        this%wa = Ini%Read_Double('wa', 0.d0)
	    this%SteepnessDE = Ini%Read_Double('SteepnessDE', 0.5_dl)
	    this%atrans = Ini%Read_Double('atrans', 0.5_dl)
        this%w_m = Ini%Read_Double('w_m', -1.d0)
        ! trap dark energy becoming important at high redshift 
        ! (will still work if this test is removed in some cases)
        if (this%w_lam + this%wa > 0) &
             error stop 'w + wa > 0, giving w>0 at high redshift'
    else
        call File%LoadTxt(Ini%Read_String('wafile'), table)
        call this%SetwTable(table(:,1),table(:,2), size(table(:,1)))
    endif

    end subroutine TDarkEnergyEqnOfState_ReadParams


    subroutine TDarkEnergyEqnOfState_Init(this, State)
    use classes
    class(TDarkEnergyEqnOfState), intent(inout) :: this
    class(TCAMBdata), intent(in), target :: State

    this%is_cosmological_constant = .not. this%use_tabulated_w .and. &
        &  abs(this%w_lam + 1._dl) < 1.e-6_dl .and. this%wa==0._dl

    end subroutine TDarkEnergyEqnOfState_Init


    end module DarkEnergyInterface