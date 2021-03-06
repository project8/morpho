'''
Perform Stan diagnostic tests

Source: Michael Betancourt,
https://github.com/betanalpha/jupyter_case_studies/blob/master/pystan_workflow/stan_utility.py
Modified by Talia Weiss, 1-23-18
Ported to morpho 2 by Joe Johnston, 5-20-19

These tests are motivated here:
http://mc-stan.org/users/documentation/case-studies/pystan_workflow.html

Functions:
  - check_div: Check how many transitions ended with a divergence
  - check_treedepth: Check how many transitions failed due to tree depth
  - check_energy: Check energy Bayesian fraction of missing information
  - check_n_eff: Check the effective sample size per iteration
  - check_rhat: Check the potential scale reduction factors
  - check_all_diagnostics: Check all MCMC diagnosticcs
  - partition_div: Get divergent and non-divergent parameter arrays
'''

try:
    # import pystan
    import numpy
except ImportError:
    pass


def check_div(fit):
    '''Check how many transitions ended with a divergence

    Args:
        fit: stanfit object containing sampler output

    Returns:
        (bool, str): Boolean specifying whether any iteration are
        divergent, and string stating the number of transitions
        that ended with a divergence
    '''
    sampler_params = fit.get_sampler_params(inc_warmup=False)
    divergent = [x for y in sampler_params for x in y['divergent__']]
    n = sum(divergent)
    N = len(divergent)
    if n > 0:
        return((True, '{} of {} iterations ended with a divergence ({}%).'.format(n, N,
                                                                                  100 * n / N)+' Try running with larger adapt_delta to remove the divergences.'))
    else:
        return((False, '{} of {} iterations ended with a divergence ({}%).'.format(n, N,
                                                                                   100 * n / N)))


def check_treedepth(fit, max_depth=10):
    '''Check how many transitions ended prematurely due to tree depth

    A transition may end prematurely if the maximum tree depth limit is
    exceeded.

    Args:
        fit: stanfit object containing sampler output
        max_depth: Maximum depth used to check tree depth

    Returns:
        (bool, str): Boolean specifying whether any iterations
        passed the given max dpeth, and string stating the number
        of transitions that passed the given max_depth.
    '''
    sampler_params = fit.get_sampler_params(inc_warmup=False)
    depths = [x for y in sampler_params for x in y['treedepth__']]
    n = sum(1 for x in depths if x == max_depth)
    N = len(depths)
    if n > 0:
        return((True, ('{} of {} iterations saturated the maximum tree depth of {}.'
                       + ' ({}%)').format(n, N, max_depth, 100 * n / N)+' Run again with max_depth set to a larger value to avoid saturation.'))
    else:
        return((False, ('{} of {} iterations saturated the maximum tree depth of {}.'
                        + ' ({}%)').format(n, N, max_depth, 100 * n / N)))


def check_energy(fit):
    '''Checks the energy Bayesian fraction of missing information (E-BFMI)

    Args:
        fit: stanfit object containing sampler output

    Returns:
       (bool, str): Boolean specifying whether E-BFMI is less than 0.2,
       and string warning that the model may need to be reparametrized if
       E-BFMI is less than 0.2
    '''
    sampler_params = fit.get_sampler_params(inc_warmup=False)
    no_warning = True
    for chain_num, s in enumerate(sampler_params):
        energies = s['energy__']
        numer = sum((energies[i] - energies[i - 1]) **
                    2 for i in range(1, len(energies))) / len(energies)
        denom = numpy.var(energies)
        if numer / denom < 0.2:
            print('Chain {}: E-BFMI = {}'.format(chain_num, numer / denom))
            no_warning = False
    if no_warning:
        return((False, 'E-BFMI indicated no pathological behavior.'))
    else:
        return((True, 'E-BFMI below 0.2 indicates you may need to reparameterize your model.'))


def check_n_eff(fit):
    '''Checks the effective sample size per iteration

    Args:
        fit: stanfit object containing sampler output

    Returns:
        (bool, str): Boolean and string stating whether the
        effective sample size indicates an issue
    '''
    fit_summary = fit.summary(probs=[0.5])
    n_effs = [x[4] for x in fit_summary['summary']]
    names = fit_summary['summary_rownames']
    n_iter = len(fit.extract()['lp__'])

    no_warning = True
    for n_eff, name in zip(n_effs, names):
        ratio = n_eff / n_iter
        if (ratio < 0.001):
            print('n_eff / iter for parameter {} is {}!'.format(name, ratio))
            print('E-BFMI below 0.2 indicates you may need to reparameterize your model.')
            no_warning = False
    if no_warning:
        return((False, 'n_eff / iter looks reasonable for all parameters.'))
    else:
        return((True, '  n_eff / iter below 0.001 indicates that the effective sample size has likely been overestimated.'))


def check_rhat(fit):
    '''Checks the potential scale reduction factors

    Args:
        fit: stan fit object containing sampler output

    Returns:
        (bool, str): Boolean and string stating whether
        the Rhat values indicate an error
    '''
    from math import isnan
    from math import isinf

    fit_summary = fit.summary(probs=[0.5])
    rhats = [x[5] for x in fit_summary['summary']]
    names = fit_summary['summary_rownames']

    no_warning = True
    for rhat, name in zip(rhats, names):
        if (rhat > 1.1 or isnan(rhat) or isinf(rhat)):
            print('Rhat for parameter {} is {}!'.format(name, rhat))
            no_warning = False
    if no_warning:
        return((False, 'Rhat looks reasonable for all parameters.'))
    else:
        return((True, 'Rhat above 1.1 indicates that the chains very likely have not mixed.'))


def check_all_diagnostics(fit):
    '''Checks all MCMC diagnostics

    Args:
        fit: stanfit object containing sampler output

    Returns:
        (bool, list of str): Boolean specifying whether any checks indicate
        possible isssues, and list of strings indicating the results of the
        checks for divergence, treee depth, energy Bayesian fraction
        of missing energy, effective sample size, and Rhat
    '''
    n_eff_warn, n_eff_str = check_n_eff(fit)
    rhat_warn, rhat_str = check_rhat(fit)
    div_warn, div_str = check_div(fit)
    treedepth_warn, treedepth_str = check_treedepth(fit)
    energy_warn, energy_str = check_energy(fit)
    warn = n_eff_warn or rhat_warn or div_warn or \
        treedepth_warn or energy_warn
    check_str = n_eff_str + '\n' + rhat_str + '\n' + div_str + \
        '\n' + treedepth_str + '\n' + energy_str
    return((warn, check_str))


def partition_div(fit_results, parameter_name):
    ''' Returns parameter arrays for divergent and non-divergent transitions

    Args:
        fit_results: results generated by PyStanSamplingProcessor
        parameter_name: str with name of parameter whose data should
            be extracted

    Returns:
        (list, list): The first list contains all nondivergent
        transitions, the second contains all divergent transitions.
        Warmup iterations are excluded from the returned arrays
    '''
    warmup = fit_results["is_sample"].count(0)
    div = numpy.array(fit_results['divergent__'][warmup:]).astype('int')
    data = numpy.array(fit_results[parameter_name][warmup:])
    nondiv_params = data[div == 0]
    div_params = data[div == 1]
    return nondiv_params, div_params
