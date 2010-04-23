# -*- coding: utf-8 -*-
{
  'languages' => ['en'],
  'time_zone' => 'Pacific Time (US & Canada)',

  'roles' => {
    'admin'            => { :landing_page => '/' },
    'manager'            => { :landing_page => '/' },
    'observer'           => { :landing_page => '/observer' },
    'field_coordinator'  => { :landing_page => '/' },
  },

  'administrative_area_hierarchy' => ['Country', 'Province', 'District'],

  'administrative_areas' => {
    'Pacific Northwest' => {
      'Province' => {
        'Washington' => {
          'District' => {
            'Seattle' => {
              'population' => 602000,
              'latitude' => 47.60972,
              'longitude' => -122.33306,
            },
            'Yakima' => {
              'population' => 84074,
              'latitude' => 46.596728, 
              'longitude' => -120.529656            
            }
          }
        },
        'Oregon' => {
          'default' => true,
          'population' => 	3825657,
          'District' => {
            'Portland' => {
              'latitude' => 45.52,
              'longitude' => -122.681944,
              'population' => 582130,
            },
            'Hermiston' => {
              'latitude' => 45.533,
              'longitude' => -122.584,
              'population' => 14953,
            },
          },
        },
      },
    },
  },

  'health_centers' => {
    'Downtown Portland Health Center'  => { 'District' => 'Portland',  'DeliveryZone' => 'Western Oregon', 'population' => 10000 },
    'North Portland Health Center'     => { 'District' => 'Portland',  'DeliveryZone' => 'Western Oregon', 'population' => 10000 },
    'Seattle Health Center'            => { 'District' => 'Seattle',   'DeliveryZone' => 'Puget Sound', 'population' => 10000 },
    'Hermiston Health Center'          => { 'District' => 'Hermiston', 'DeliveryZone' => 'Eastern Oregon', 'population' => 10000 },
    'Yakima Health Centeer'            => { 'District' => 'Yakima',    'DeliveryZone' => 'Tri-Cities', 'population' => 10000 }
  },

  'warehouses' => {
    'Oregon Warehouse' => {
      'Province' => 'Oregon',
      'DeliveryZones' => ['Western Oregon', 'Eastern Oregon'],
    },
    'Washington Warehouse' => {
      'Province' => 'Washington',
      'DeliveryZones' => ['Washington'],
    },
  },

  'packages' => [
    {
      'code'       =>'polio10',
      'product'    =>'polio',
      'quantity'   => 10,
    },
    {
      'code'       =>'polio20',
      'product'    =>'polio',
      'quantity'   => 20,
    },
    {
      'code'       =>'penta',
      'product'    =>'penta',
      'quantity'   => 1,
    },
    {
      'code'       =>'measles',
      'product'    =>'measles',
      'quantity'   => 10,
    },
    {
      'code'       =>'bcg',
      'product'    =>'bcg',
      'quantity'   => 20,
    },
    {
      'quantity' => 1,
      'code' =>'syringe5ml',
      'product' =>'syringe5ml'
    },
    {
      'quantity' => 1,
      'code' =>'syringe05ml',
      'product' =>'syringe05ml'
    },
    {
      'quantity' => 1,
      'code' =>'syringe005ml',
      'product' =>'syringe005ml'
    },
  ],

  'product_types' => [
    {
      'code'      =>'vaccine',
      'trackable' => true
    },
    {
      'code'      =>'syringe',
      'trackable' => true
    },
  ],

  'products' => [
    {
      'type' =>'vaccine',
      'code' =>'polio',
    },
    {
      'type' =>'vaccine',
      'code' =>'penta',
    },
    {
      'type' =>'vaccine',
      'code' =>'bcg',
    },
    {
      'type' =>'vaccine',
      'code' =>'measles',
    },
    {
      'type' =>'syringe',
      'code' =>'syringe5ml'
    },
    {
      'type' =>'syringe',
      'code' =>'syringe05ml'
    },
    {
      'type' =>'syringe',
      'code' =>'syringe005ml'
    },
  ],

  'equipment' => ['burner','lamp','extinguisher','transport'],

  'cold_chain' => [
    {
      'code' =>'smallpropane',
      'capacity' => 10.00,
      'description' =>'Small Propane',
      'power_source' =>'Propane',
    },
    {
      'code' =>'smallelectric',
      'capacity' => 12.00,
      'description' =>'Small Electric',
      'power_source' =>'electric'
    },
    {
      'code' =>'smallsolar',
      'capacity' => 8.00,
      'description' =>'Small Solar',
      'power_source' =>'Solar',
    },
    {
      'code' =>'petrol',
      'capacity' => 0.00,
      'description' =>'',
      'power_source' =>'',
    }
  ],

  'fridge_statuses' => ['OPER','BURN','GAS','FAULT','THERM','OTHER','OK'],
  
  'stock_cards' => ['polio','penta','bcg'],

  'descriptive_categories' => {
    'sex'             => ['m','f'],
    'child_regimen'   => ['polio0','polio1','polio2','polio3','penta1','penta2','penta3','bcg','measles'],
    'child_age_range' => ['months0_11','months12_23'],
    'strategy'        => ['hc','mb'],
  },
  
  'targets' => {
    'polio1'  => { 'tally' => 'ChildVaccinationTally', 'percentage' => 3.9, 'values' => ['child_regimen:polio1'] },
    'polio3'  => { 'tally' => 'ChildVaccinationTally', 'percentage' => 3.9, 'values' => ['child_regimen:polio3'] },
    'full'    => { 'tally' => 'FullVaccinationTally',  'percentage' => 4.0, 'values' => ['sex:m', 'sex:f', 'strategy:hc', 'strategy:mb'] },
  },
 
  'visit_screens' => %w(cold_chain epi_inventory equipment_status stock_cards usage_tallies full_vaccination_tallies child_vaccination_tallies),
  
  'tallies' => {
    'ChildVaccinationTally' => {
      'tally_fields' => ['value'],

      'descriptive_categories' => [
        ['regimen'   , {'category_code' =>'child_regimen' }  ],
        ['age_range' , {'category_code' =>'child_age_range' }],
        ['strategy'  , {'category_code' =>'strategy' }       ],
      ],

      'exclude_combinations' => [
        {'regimen' =>'polio0','age_range' =>'months12_23' }
      ],

      'form_tables' => {
        'standard' => {
          'row_groups' => [
            ['regimen']
          ],
          'column_groups' => [
            ['age_range','strategy']
          ]
        }
      },
    },

    'FullVaccinationTally' => {
      'tally_fields' => ['value'],

      'descriptive_categories' => [
        ['sex'       , {'category_code' =>'sex'      }],
        ['strategy'  , {'category_code' =>'strategy' }],
      ],

      'form_tables' => {
        'standard' => {
          'row_groups' => [
            ['sex']
          ],
          'column_groups' => [
            ['strategy']
          ]
        }
      }
    },

    'UsageTally' => {
      'tally_fields' => ['doses_received','doses_distributed','loss','open_vials'],
      'date_fields'  => ['expiration'],

      'dimensions'   => ['Product.vaccine'],


      'form_tables' => {
        'standard' => {
          'row_groups' => [
          ['vaccine']
          ],
          'column_groups' => [
            ['doses_received'],
            ['doses_distributed'],
            ['loss'],
            ['open_vials'],
            ['expiration']
          ]
        },
      },
    },
  },
}
