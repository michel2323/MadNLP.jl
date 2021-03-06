include("nlp_test_include.jl")

@test begin
    m=Model(MadNLP.Optimizer)
    @variable(m,x)
    @objective(m,Min,x^2)
    MOIU.attach_optimizer(m)

    nlp = MadNLP.NonlinearProgram(m.moi_backend.optimizer.model)
    ips = MadNLP.Solver(nlp)
    
    show(stdout, "text/plain",nlp)
    show(stdout, "text/plain",ips)
    true
end


sets = [
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Umfpack,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:Umfpack)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Mumps,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:Mumps)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Ma27,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:Ma27)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Ma57,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:Ma57)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Ma77,
            print_level=MadNLP.ERROR),
        ["unbounded"],
        isdefined(MadNLP,:Ma77)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Ma86,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:Ma86)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Ma97,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:Ma97)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.Pardiso,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:Pardiso)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.PardisoMKL,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:PardisoMKL)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.LapackMKL,
            lapackmkl_algorithm=MadNLP.LapackMKL.BUNCHKAUFMAN,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:LapackMKL)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.LapackMKL,
            lapackmkl_algorithm=MadNLP.LapackMKL.LU,
            print_level=MadNLP.ERROR),
        [],
        isdefined(MadNLP,:LapackMKL)
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.LapackCUDA,
            lapackcuda_algorithm=MadNLP.LapackCUDA.BUNCHKAUFMAN,
            print_level=MadNLP.ERROR),
        [],
        has_cuda_gpu()
    ],
    [
        ()->MadNLP.Optimizer(
            linear_solver=MadNLP.LapackCUDA,
            lapackcuda_algorithm=MadNLP.LapackCUDA.LU,
            print_level=MadNLP.ERROR),
        [],
        has_cuda_gpu()
    ],
    [
        ()->MadNLP.Optimizer(
            fixed_variable_treatment=MadNLP.RELAX_BOUND,
            print_level=MadNLP.ERROR),
        [],
        true
    ],
    [
        ()->MadNLP.Optimizer(
            tol=1e-8,
            reduced_system=false,
            print_level=MadNLP.ERROR),
        ["infeasible"], # numerical error at the end],
        true
    ],
    [
        ()->MadNLP.Optimizer(
            tol=1e-8,
            inertia_correction_method=MadNLP.INERTIA_FREE,
            reduced_system=false),
        ["infeasible","eigmina"], # numerical errors
        true
    ],
    [
        ()->MadNLP.Optimizer(
            inertia_correction_method=MadNLP.INERTIA_FREE,
            print_level=MadNLP.ERROR),
        [],
        true
    ],
    [
        ()->MadNLP.Optimizer(
            iterator=MadNLP.Krylov,
            print_level=MadNLP.ERROR),
        ["unbounded"],
        true
    ],
    [
        ()->MadNLP.Optimizer(
            linear_system_scaler=isdefined(MadNLP,:Mc19) ? MadNLP.Mc19 : MadNLP.DummyModule,
            print_level=MadNLP.ERROR),
        ["eigmina"],
        true
    ],
    [
        ()->MadNLP.Optimizer(
            disable_garbage_collector=true,
            output_file=".test.out"
        ),
        ["infeasible","unbounded","eigmina"], # just checking logger; no need to test all
        isdefined(MadNLP,:Umfpack )
    ],
]

@testset "NLP test" for (optimizer_constructor,exclude,availability) in sets
    availability && nlp_test(optimizer_constructor,exclude)
end
