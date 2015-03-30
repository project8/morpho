/*
* Tritium Spectrum Model (Generator)
* -----------------------------------------------------
* Copyright: J. A. Formaggio <josephf@mit.edu>
*
* Date: 25 September 2014
*
* Purpose: 
*
*		Program will generate a set of sampled data distributed according to the beta decay spectrum of tritium.
*		Program assumes Project-8 measurement (frequency) and molecular tritium as the source.
*		Spectrum includes simplified beta-function with final state distribution (assuming 0.36 eV gaussian model)
*		Includes broadening due to magnetic field homogeneity, radiative energy loss, Doppler and scattering.
*		T_2 scattering cross-section model implemented.
*		Note that sample events are distributed according to true distribution.  
*
*
* Collaboration:  Project 8
*/

functions{

// Set up constants 

	real m_electron() { return  510998.910;}				// Electron mass in eV
	real c() { return  299792458.;}			   	   	 	// Speed of light in m/s
	real omega_c() {return 1.758820088e+11;}		         	// Angular gyromagnetic ratio in rad Hz/Tesla
	real freq_c() {return omega_c()/(2. * pi());}			 	// Gyromagnetic ratio in Hz/Tesla
	real alpha() { return 7.29735257e-3;}               	   	 	// Fine structure constant
	real bohr_radius() { return 5.2917721092e-11;}	 	 	 	// Bohr radius in meters
	real k_boltzmann() {return  8.61733238e-5;}		         	// Boltzmann's constant in eV/Kelvin
	real unit_mass() { return 931.494061e6;}			 	// Unit mass in eV
	real r0_electron() { return square(alpha())*bohr_radius();}  	 	// Electron radius in meters
	real ry_hydrogen() { return 13.60569253;}                    	    	// Rydberg energy in eV
	real cyclotron_rad(real B) {return (4./3.)*r0_electron()/c()*square(omega_c() * B);}    // Frequency damping constant (in units of Hz/Tesla^2)
	real seconds_per_year() {return 365.25 * 86400.;}	        	// Seconds in a year

//  Tritium-specific constants

    	real tritium_rate_per_eV() {return 2.0e-13;}				 // fraction of rate in last 1 eV
    	real tritium_molecular_mass() {return  2. * 3.016 * unit_mass();}   	 // Molecular tritium mass in eV
	real tritium_halflife() {return 12.32 * seconds_per_year();}  // Halflife of tritium (in seconds)
	
// Method for converting kinetic energy (eV) to frequency (Hz).  
// Depends on magnetic field (Tesla)

   	real get_frequency(real kinetic_energy,real field) {
	     real gamma;
	     gamma <- 1. +  kinetic_energy/m_electron();
	     return freq_c() / gamma * field;
	}

// Method for converting frequency (Hz) to kinetic energy (eV)
// Depends on magnetic field (Tesla)

   	real get_kinetic_energy(real frequency, real field) {
	     real gamma;
	     gamma <- freq_c() / frequency * field;
	     return (gamma -1.) * m_electron();
	}

//  Create a centered normal distribution function for faster convergence on normal distributions

	real vnormal_lp(real beta_raw, real mu, real sigma) {
	       beta_raw ~ normal(0,1);
	       return mu + beta_raw * sigma;
	}

//  Create a centered normal distribution function for faster convergence on cauchy distributions.
//  IMPORTANT: The beta_raw input must be distributed within bounds of -pi/2 to +pi/2.

	real vcauchy_lp(real beta_raw, real mu, real sigma) {
	       beta_raw ~ uniform(-pi()/2. , +pi()/2.);
	       return mu +  tan(beta_raw) * sigma;
	}

//   Get relativistic velocity (beta)

        real get_velocity(real kinetic_energy) {

	      real gamma;
	      real beta;

      	      gamma <-1. +  kinetic_energy/m_electron();
	      beta <- sqrt(square(gamma)-1.)/gamma;
	      return beta;

	}

//  Beta decay function given an endpoint Q, and neutrino mass m, and a kinetic energy KE (valid only near the tail)

        real get_beta_function_log(real KE, real Q, real m_nu, real minKE) {

	     real log_rate;
	     real log_norm;
	     
	     log_norm <- 1.5 * log(square(Q - minKE) - square(m_nu));	     
	     log_rate <- log(3.) + log(Q - KE) + 0.5 * log(square(KE - Q) - square(m_nu));		

	     return (log_rate-log_norm);
	}


//  Total cross-section (in 1/(meters)^2)
//  Based on the paper Binary-encounter-dipole model for electron-impact ionization
//  Yong-Ki Kim and M. Eugene Rudd, Phys. Rev. A 50, 3954

        real xsection(real kinetic_energy, real ave_kinetic, real bind_energy, real msq, real Q) {
	     real beta;
	     real d_inf;
	     real S;
	     real xsec;
	     real t_energy;
	     real u_energy;
	     real b_energy;

	     beta <- get_velocity(kinetic_energy);
	     b_energy <- bind_energy;
	     t_energy <- (0.5 * m_electron() * beta * beta) / b_energy;
	     u_energy <- ave_kinetic / b_energy;

	     S <- 4.0 * pi() * square(bohr_radius()) / (t_energy + u_energy + 1) * square(ry_hydrogen()/b_energy);
	     d_inf <- b_energy * msq / ry_hydrogen();
	     xsec <- S * (d_inf * log(t_energy) + (2 - Q) * (1.0 - 1.0/t_energy - log(t_energy)/(1.0+t_energy)));
	     
	     return xsec;
	}

//  Butterworth-type filter.

       real filter_log(real s, real s_min, real s_max, real n) {
	     return -1./2. * ( log1p(pow(s_min/s,2.*n)) +log1p(pow(s/s_max,2.*n)) );
       }

}

data {

//   Number of samples to generate (to get event statistics correct)

     int nGenerate;

//   Number of neutrinos and mixing parameters

     real neutrino_mass_limit;

//   Primary magnetic field (in Tesla)

     real<lower=0> BField;
     real BFieldError;

//   Range for fits (in Hz)

     real<lower=0 > minKE;
     real<lower=minKE> maxKE;

//   Endpoint of tritium, in eV

     real<lower=0> QValue;
     real sigmaQ;

//  Cross-section of e-T2 , in meter^-2

    real xsec_avekin;
    real xsec_bindkin;
    real xsec_msq;
    real xsec_Q;

//  Conditions of the experiment and measurement

    real number_density;				//  Tritium number density (in meter^-3)
    real temperature;				//  Temperature of gas (in Kelvin)
    real effective_volume;		        //  Effective volume (in meter^3)
    real measuring_time;			//  Measuring time (in seconds)

//  Background rate

    real background_rate;			//  Background rate in Hz

//  Clock and filter information

    real fBandpass;
    real fclockError;
    int  fFilterN;

}


transformed data {

    real minFreq;
    real maxFreq;
    real fclock;
    real activity;

    minFreq <- get_frequency(maxKE, BField);
    maxFreq <- get_frequency(minKE, BField);

    fclock <- minFreq;

    if (fBandpass > (maxFreq-minFreq)) {
       print("Bandpass filter (",fBandpass,") is greater than energy range (",maxFreq-minFreq,").");
       print("Consider enlarging energy region.");
    }

    activity <- tritium_rate_per_eV() * pow(QValue - minKE,3) * number_density * effective_volume / (tritium_halflife() / log(2.) );
    print("total activity = ",activity * measuring_time, " events over ",measuring_time," seconds.")

}

parameters {

    real<lower=minKE,upper=maxKE> KE;
    real uQ;
    real uB;
    real eDop;
    real df;
    real<lower=0.0, upper=neutrino_mass_limit> neutrino_mass;
}

transformed parameters{

    real signal_rate;
    real<lower=0> MainField;
    real beta;
    real Q;
    real frequency; 

    real xsec;
    real<lower=0> scatt_width;
    real rad_width;
    real tot_width;

    real duration;
    real sigma_freq;
    real freq_recon;
    
    real kDoppler;
    real KE_shift;

    real signal_log;
    real background_log;
    real rate_log;
    real signal_fraction;

    beta <- get_velocity(KE);

    signal_fraction <- activity/(activity + background_rate);

// Obtain magnetic field (with prior distribution)

    MainField <- vnormal_lp(uB, BField, BFieldError);
     
// Dispersion due to uncertainty in final states (with prior distribution)

    Q <- vnormal_lp(uQ, QValue, sigmaQ);

//   Calculate scattering length, radiation width, and total width;

    xsec <- xsection(KE,  xsec_avekin, xsec_bindkin, xsec_msq, xsec_Q);
    scatt_width <- number_density * c() * beta * xsec;

    rad_width <- cyclotron_rad(MainField);
    tot_width <- (scatt_width + rad_width);
    sigma_freq <- (scatt_width + rad_width) / (4. * pi());    

//   Calculate Doppler shift effect

    frequency <- get_frequency(KE, MainField);

    freq_recon <- frequency + df;

    kDoppler <-  2. * KE / beta * sqrt(eDop / tritium_molecular_mass());

    background_log <- log(1.-signal_fraction) - log(maxKE - minKE);

    KE_shift <- KE + kDoppler;

    if (KE_shift < (Q-neutrino_mass)) {
       signal_log <- log(signal_fraction) + get_beta_function_log(KE_shift, Q, neutrino_mass, minKE);
       rate_log <- log_sum_exp(signal_log,  background_log);
    }else {
       rate_log <- background_log;
    }

}

model {

# Thermal Doppler broadening of the tritium source

    eDop ~ gamma(1.5,1./(k_boltzmann() * temperature));

    df ~ cauchy(0.0, sigma_freq);
    
    freq_recon ~ filter(minFreq, maxFreq, fFilterN);

    increment_log_prob(rate_log);    

}


generated quantities {

    real KE_recon;

    int isOK;
    int nData;
    int  events;
    real freq_data;
    real time_data;
    real rate_data;
    real fbandpass;

#   Simulate duration of event

    KE_recon <- get_kinetic_energy(freq_recon, MainField);

# Compute the number of events that should be simulated for a given frequency/energy.  Assume Poisson distribution.
    
    nData <- nGenerate;

    time_data <- exponential_rng(scatt_width);

    freq_data <- freq_recon - fclock;

    isOK <- (freq_data > 0.);

    rate_data <- (activity + background_rate) * exp(rate_log) * measuring_time;
    
    events <- poisson_rng((activity + background_rate) * exp(rate_log) * measuring_time / nGenerate);

}