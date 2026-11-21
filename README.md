# vex-tpl-springboot-azure-critical

Plantilla de pipeline de vex que despliega una aplicación Spring Boot en **Azure Kubernetes Service (AKS)**, sin ningún secreto: el pipeline entra a Azure con identidad federada (OIDC).

| Paso | Qué hace | Entra a Azure |
|---|---|---|
| `test` | `mvn clean verify` | no |
| `acr` | Terraform: el registro de contenedores del ambiente | sí |
| `supply` | Terraform: el clúster de AKS del ambiente | sí |
| `package` | `az acr build`: la imagen se construye en Azure, y se anota su digest | sí |
| `deploy` | `kubectl apply` de los manifiestos, con la imagen **por digest**, y espera a que el despliegue termine | sí |

Ambientes: `sand`, `stag` y `prod`. La configuración de cada paso está en `config.yaml`; los valores por ambiente, en `variables/<ambiente>/`.

## Cómo se conecta la nube

Contrato requerido: `azure/v1`.

```
az login
vex bootstrap <ambiente>
vex run deploy <ambiente>
```

`vex bootstrap` aplica **el bootstrap de este pipeline** (`bootstrap/azure/`) con tu sesión de `az`. vex no decide qué permisos se dan: aplica lo que dice esa carpeta, te lo enseña antes y espera tu confirmación. Tu cuenta debe poder crear grupos de recursos y asignar roles en la suscripción (por ejemplo, Owner).

Lo único que añade vex es la confianza: después de desplegar la plantilla crea la credencial federada `vex-oidc` sobre la identidad de despliegue. La plantilla no trae credenciales federadas.

## Qué crea el bootstrap

Un despliegue de suscripción llamado `vex-bootstrap-<slug>-<ambiente>`, por cada ambiente:

| Recurso | Nombre | Para qué |
|---|---|---|
| Grupo de recursos de carga | `rg-vex-<slug>-<ambiente>` | Donde el pipeline crea el registro y el clúster |
| Grupo de recursos de identidades | `rg-vex-<slug>-<ambiente>-id` | Separa las identidades y el estado de Terraform de lo que el pipeline puede gestionar |
| Identidad de despliegue | `id-vex-<slug>-<ambiente>-deploy` | Con la que el pipeline entra a Azure |
| Identidad del clúster | `id-vex-<slug>-<ambiente>-aks` | Plano de control de AKS |
| Identidad del kubelet (`pull` del contrato) | `id-vex-<slug>-<ambiente>-kubelet` | Con la que los nodos descargan las imágenes |
| Candado `CanNotDelete` | `vex-protect-identities` | Evita borrar por accidente el grupo de identidades |
| Cuenta de almacenamiento | `st<único><nombre>` (24 caracteres) con el contenedor `tfstate`, en el grupo de identidades | Estado de Terraform de los pasos `acr` y `supply` |
| Presupuesto (opcional) | `vex-<slug>-<ambiente>` | Aviso al 80 % del gasto mensual del grupo de carga y del de nodos |

La cuenta de almacenamiento no admite llaves de cuenta ni acceso público, y guarda versiones. Los grupos llevan las etiquetas `vex:managed`, `vex:project` y `vex:environment`.

El grupo de nodos (`rg-vex-<slug>-<ambiente>-nodes`) no lo crea el bootstrap: lo crea AKS con ese nombre cuando `supply` crea el clúster.

### Permisos que da, y a quién

| Identidad | Rol | Ámbito |
|---|---|---|
| Despliegue | Contributor | Grupo de recursos de carga |
| Despliegue | Azure Kubernetes Service RBAC Cluster Admin | Grupo de recursos de carga |
| Despliegue | Storage Blob Data Contributor | Contenedor `tfstate` de la cuenta de estado |
| Despliegue | Managed Identity Operator | Identidad del clúster |
| Despliegue | Managed Identity Operator | Identidad del kubelet |
| Clúster | Managed Identity Operator | Identidad del kubelet |
| Kubelet | AcrPull | Grupo de recursos de carga |

No hay ningún rol sobre la suscripción, ni Owner, ni User Access Administrator. **Los pasos del pipeline no asignan roles ni usan Microsoft Graph**: todo permiso se decide aquí, y quien acepta el bootstrap lo ve antes de aplicarlo.

Por qué cada uno:

- **Contributor sobre el grupo de carga**: `acr` crea en él el registro y `supply` el clúster; `package` construye la imagen en el registro (`az acr build` exige permisos de gestión sobre el registro, no basta `AcrPush`).
- **RBAC Cluster Admin**: Contributor crea el clúster, pero no da acceso a la API de Kubernetes. El clúster no tiene cuentas locales y autoriza con roles de Azure; `deploy` crea el namespace y su cuota, que son objetos de todo el clúster. Va sobre el grupo porque el clúster aún no existe.
- **Storage Blob Data Contributor sobre el contenedor**: Terraform lee, escribe y bloquea su estado. Es un rol de datos y va solo sobre el contenedor. La cuenta vive en el grupo de identidades, donde la identidad de despliegue no gestiona nada: si estuviera en el grupo de carga, su Contributor le dejaría reactivar las llaves de cuenta, quitar el versionado o borrarla.
- **Identidades creadas antes que el clúster**: así `AcrPull` se da en el bootstrap, sobre el grupo donde vivirá el registro, y el pipeline no necesita poder asignar roles. AKS exige que la identidad del clúster sea Managed Identity Operator de la del kubelet.

### Nada se comparte entre ambientes

Cada ambiente tiene sus grupos, su registro, su estado de Terraform y sus identidades. La identidad de despliegue de `sand` no tiene ningún permiso sobre lo que usa `prod`: no puede escribir en su registro ni en su estado.

Compartir un registro entre ambientes ahorra unos US$ 5 al mes por ambiente y permite promover la misma imagen, pero **abre una escalada de `sand` a `prod`** que esta plantilla no acepta por defecto:

- `az acr build` exige permisos de gestión sobre el registro, así que la identidad de cada ambiente podría publicar, mover etiquetas o borrar imágenes que producción descarga;
- el estado de Terraform del registro sería de todos: quien lo escribe decide qué hace el `terraform apply` del siguiente ambiente, también el de producción.

Si aun así lo quieres, hazlo en tu copia y a sabiendas: crea el grupo y el estado compartidos en el bootstrap, da a cada identidad de despliegue solo lo imprescindible sobre ellos, marca el paso `acr` como `scope: shared` en `config.yaml` y quita `${var.environment}` de la clave de su estado. Mantén siempre el despliegue por digest, y considera que solo un ambiente de confianza construya y los demás tengan `AcrPull`.

### Despliegue por digest

`package` construye `<proyecto>:<versión>` y anota el digest (`sha256:…`) de la imagen; el manifiesto que aplica `deploy` usa `<proyecto>@sha256:…`, nunca la etiqueta. Una etiqueta se puede mover a otra imagen; un digest identifica el contenido. No se publica `latest`.

### Presupuesto

Por defecto no se crea. Azure exige un importe y al menos un correo de aviso, y vex solo pasa a la plantilla `projectId`, `projectSlug`, `environment` y `location`. Para tenerlo, cambia en tu copia de `bootstrap/azure/main.bicep` los valores por defecto de `budgetAmount` y `budgetEmails`, y vuelve a compilar.

### Mantener el bootstrap

Se despliega `main.json`, no el Bicep. Después de cambiar un `.bicep`:

```
az bicep build --file bootstrap/azure/main.bicep --outfile bootstrap/azure/main.json
```

El flujo `validar` falla si `main.json` no corresponde a `main.bicep`, o si la plantilla trae credenciales federadas, scripts de despliegue o plantillas remotas. Cambiar cualquier archivo de la carpeta cambia su huella: `vex run` se detendrá y pedirá repetir `vex bootstrap <ambiente>`.

## Qué crea el pipeline y cuánto cuesta

| Paso | Recurso | Costo aproximado |
|---|---|---|
| `acr` | Registro de contenedores, SKU Basic, uno por ambiente | US$ 5 al mes |
| `supply` | Clúster de AKS (plano de control gratuito) | sin costo fijo |
| `supply` | Nodos: `sand` 1 × `Standard_A2_v2`; `stag` 1 × `Standard_A4_v2`; `prod` 2 × `Standard_A4_v2` | US$ 65 al mes (`sand`), 140 (`stag`), 280 (`prod`) |
| `deploy` | Balanceador de carga estándar con IP pública (servicio `LoadBalancer`) | US$ 20 a 25 al mes |

El almacenamiento del estado cuesta céntimos al mes. Las identidades, los grupos y el candado no tienen costo. Son cifras orientativas de `eastus` con pago por uso: revisa la calculadora de Azure para tu región. **El clúster cuesta aunque la aplicación no reciba tráfico.**

El tamaño y el número de nodos se cambian en `variables/<ambiente>/supply.yaml`; los recursos de la aplicación, en `variables/<ambiente>/deploy.yaml`.

## Requisitos de la aplicación

- Proyecto Maven con Spring Boot y Java 17 (`pom.xml` y `src/` en la raíz).
- `spring-boot-starter-actuator` con las sondas `/actuator/health/liveness` y `/actuator/health/readiness`.
- La app escucha en el puerto 8080.
- El manifiesto `ingress.yaml` supone un controlador `nginx` y `cert-manager` en el clúster; esta plantilla no los instala. La aplicación se publica por el servicio `LoadBalancer`.
- Las imágenes base del `Dockerfile` (Maven y Temurin) se descargan de Docker Hub sin credenciales: `az acr build` puede toparse con su límite de descargas anónimas.

## Variables que entrega la CLI

Los pasos de nube empiezan con `vex-azure-login` y usan estas variables de entorno:

| Variable | Salida del bootstrap | La usa |
|---|---|---|
| `VEX_AZURE_RESOURCE_GROUP` | `resourceGroup` | `acr`, `supply`, `deploy` |
| `VEX_AZURE_STATE_ACCOUNT`, `VEX_AZURE_STATE_CONTAINER` | `stateAccount`, `stateContainer` | `acr`, `supply` |
| `VEX_AZURE_PULL_IDENTITY_ID`, `VEX_AZURE_PULL_CLIENT_ID` | `pullIdentityId`, `pullClientId` | `supply` |
| `VEX_BOOTSTRAP_PULL_PRINCIPAL_ID` | `pullPrincipalId` | `supply` |
| `VEX_BOOTSTRAP_AKS_IDENTITY_ID` | `aksIdentityId` | `supply` |
| `VEX_BOOTSTRAP_NODE_RESOURCE_GROUP` | `nodeResourceGroup` | `supply` |

Las `VEX_AZURE_*` son del contrato `azure/v1`; las `VEX_BOOTSTRAP_*` son salidas propias de este bootstrap. Terraform recibe tenant, suscripción, cliente y OIDC por las variables `ARM_*` del contrato. La imagen de runtime debe traer `az`, `terraform` con el provider `azurerm 4.57.0`, `kubectl`, `kubelogin` y `vex-azure-login`.

## Al reconectar

Si conectas el ambiente a otra suscripción, los pasos de nube se vuelven a ejecutar aunque el pipeline no haya cambiado: la conexión entra en la huella de sus variables. Por eso conservan `variables` en sus reglas de `config.yaml`.

## Desconectar

```
vex disconnect <ambiente>
```

Revoca la conexión y borra la credencial federada `vex-oidc`: desde ese momento el pipeline no puede entrar a tu suscripción. **No borra nada más**: los recursos y los roles son de quien aplicó el bootstrap. Siguen existiendo, y el clúster sigue costando:

- el grupo de carga con el registro y el clúster, y el grupo de nodos de AKS;
- el grupo de identidades con sus tres identidades, el estado de Terraform y el candado;
- las asignaciones de rol;
- el presupuesto, si lo creaste.

`vex disconnect` imprime los comandos para borrarlos. Son estos (borrar el grupo de carga borra el clúster y, con él, el grupo de nodos):

```
az group delete --name rg-vex-<slug>-<ambiente>
az lock delete --name vex-protect-identities --resource-group rg-vex-<slug>-<ambiente>-id
az group delete --name rg-vex-<slug>-<ambiente>-id
az consumption budget delete --budget-name vex-<slug>-<ambiente>
```
