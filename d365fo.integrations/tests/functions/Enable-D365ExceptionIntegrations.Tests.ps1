﻿Describe "Enable-D365ExceptionIntegrations Unit Tests" -Tag "Unit" {
	BeforeAll {
		# Place here all things needed to prepare for the tests
	}
	AfterAll {
		# Here is where all the cleanup tasks go
	}
	
	Describe "Ensuring unchanged command signature" {
		It "should have the expected parameter sets" {
			(Get-Command Enable-D365ExceptionIntegrations).ParameterSets.Name | Should -Be '__AllParameterSets'
		}
		

	}
	
	Describe "Testing parameterset __AllParameterSets" {
		<#
		__AllParameterSets -
		__AllParameterSets -
		#>
	}

}