{%- set public_domain = pillar['public-domain'] -%}
{%- from "kubernetes/map.jinja" import common with context -%}
{%- from "kubernetes/map.jinja" import master with context -%}
{%- from "kubernetes/map.jinja" import charts with context -%}

vistio-addon:
  git.latest:
    - name: https://github.com/nmnellis/vistio
    - target: /srv/kubernetes/manifests/vistio
    - force_reset: True
    - rev: v{{ charts.vistio.version }}

{% if common.addons.get('nginx', {'enabled': False}).enabled %}
/srv/kubernetes/manifests/vistio-values.yaml:
    file.managed:
    - source: salt://kubernetes/charts/vistio/files/values-mesh-only.yaml
    - user: root
    - group: root
    - mode: 644
{%- else -%}
/srv/kubernetes/manifests/vistio-values.yaml:
    file.managed:
    - source: salt://kubernetes/charts/vistio/files/values-with-ingress.yaml
    - user: root
    - group: root
    - mode: 644
{% endif %}

/srv/kubernetes/manifests/vistio-ingress.yaml:
    file.managed:
    - source: salt://kubernetes/charts/vistio/templates/ingress.yaml.j2
    - user: root
    - template: jinja
    - group: root
    - mode: 644

vistio:
  cmd.run:
    - watch:
        - git:  vistio-addon
        - file: /srv/kubernetes/manifests/vistio-values.yaml
    - runas: root
    - unless: helm list | grep vistio
    - cwd: /srv/kubernetes/manifests/vistio
    - name: |
        helm install --name vistio --namespace default \
          --values /srv/kubernetes/manifests/vistio-values.yaml \
          --set web.env.updateURL=https://{{ charts.vistio.ingress_host }}-api.{{ public_domain }}/graph \
          {%- if master.storage.get('rook_ceph', {'enabled': False}).enabled %}
          --set api.storage.class=rook-ceph-block \
          {%- endif %}
          "helm/vistio"

vistio-ingress:
    cmd.run:
      - require:
        - cmd: vistio
      - watch:
        - file: /srv/kubernetes/manifests/vistio-ingress.yaml
      - runas: root
      - name: kubectl apply -f /srv/kubernetes/manifests/vistio-ingress.yaml