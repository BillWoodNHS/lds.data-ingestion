{#- Generated models choose their schema explicitly (per-dataset databases); use it verbatim. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ lds_core.verbatim_schema_name(custom_schema_name, node) }}
{%- endmacro %}
