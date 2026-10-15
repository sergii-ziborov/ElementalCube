#include "CPhysics.h"
#include <box2d/box2d.h>
#include <stdlib.h>
#include <math.h>
struct ECWorld { b2WorldId world; b2BodyId bodies[512]; int count; };
ECWorld *ec_create(void) {
    ECWorld *w = calloc(1, sizeof(ECWorld));
    b2WorldDef def = b2DefaultWorldDef(); def.gravity = (b2Vec2){0,-18};
    w->world = b2CreateWorld(&def); return w;
}
void ec_destroy(ECWorld *w) { b2DestroyWorld(w->world); free(w); }
int ec_box(ECWorld *w, float x, float y, float width, float height, float density, bool dynamic, bool fixed) {
    int index=-1;
    for(int i=0;i<w->count;i++) if(!b2Body_IsValid(w->bodies[i])) { index=i;break; }
    if(index<0) { if(w->count>=512) return -1;index=w->count++; }
    b2BodyDef bd = b2DefaultBodyDef(); bd.type = dynamic ? b2_dynamicBody : b2_staticBody;
    bd.position = (b2Vec2){x,y}; bd.fixedRotation = fixed; bd.angularDamping = 1.0f;
    bd.isBullet = dynamic;
    b2BodyId id = b2CreateBody(w->world,&bd);
    b2ShapeDef sd = b2DefaultShapeDef(); sd.density = density;
    sd.material.friction = .48f; sd.material.restitution = .035f;
    float radius=fminf(.08f,fminf(width,height)*.2f);
    b2Polygon poly = b2MakeRoundedBox(width/2-radius,height/2-radius,radius);
    b2CreatePolygonShape(id,&sd,&poly);
    w->bodies[index]=id; return index;
}
void ec_remove(ECWorld *w, int id) { if(b2Body_IsValid(w->bodies[id])) b2DestroyBody(w->bodies[id]); }
void ec_step(ECWorld *w, float dt) { b2World_Step(w->world,dt,4); }
ECState ec_state(ECWorld *w,int id) {
    b2BodyId body=w->bodies[id]; b2Vec2 p=b2Body_GetPosition(body),v=b2Body_GetLinearVelocity(body);
    ECState s={p.x,p.y,v.x,v.y,b2Rot_GetAngle(b2Body_GetRotation(body)),b2Body_GetMass(body),b2Body_GetAngularVelocity(body),false};
    b2ContactData contacts[16]; int n=b2Body_GetContactData(body,contacts,16);
    for(int i=0;i<n;i++) {
        b2ContactData c=contacts[i]; bool isA=B2_ID_EQUALS(b2Shape_GetBody(c.shapeIdA),body);
        float normalY=c.manifold.normal.y*(isA ? -1 : 1);
        for(int j=0;j<c.manifold.pointCount;j++)
            if(normalY > .5f && c.manifold.points[j].separation < .025f) s.grounded=true;
    }
    return s;
}
void ec_impulse(ECWorld *w,int id,float vx,float vy) { float m=b2Body_GetMass(w->bodies[id]); b2Body_ApplyLinearImpulseToCenter(w->bodies[id],(b2Vec2){vx*m,vy*m},true); }
void ec_force(ECWorld *w,int id,float fx,float fy) { b2Body_ApplyForceToCenter(w->bodies[id],(b2Vec2){fx,fy},true); }
void ec_force_at(ECWorld *w,int id,float fx,float fy,float x,float y) { b2Body_ApplyForce(w->bodies[id],(b2Vec2){fx,fy},(b2Vec2){x,y},true); }
void ec_torque(ECWorld *w,int id,float torque) { b2Body_ApplyTorque(w->bodies[id],torque,true); }
void ec_rotate(ECWorld *w,int id,float angle) { b2Body_SetTransform(w->bodies[id],b2Body_GetPosition(w->bodies[id]),b2MakeRot(angle)); }
void ec_velocity(ECWorld *w,int id,float vx,float vy,float omega) {
    b2Body_SetLinearVelocity(w->bodies[id],(b2Vec2){vx,vy});b2Body_SetAngularVelocity(w->bodies[id],omega);
}
void ec_hinge(ECWorld *w,int a,int b,float x,float y) {
    b2RevoluteJointDef def=b2DefaultRevoluteJointDef();
    def.bodyIdA=w->bodies[a];def.bodyIdB=w->bodies[b];
    b2Vec2 anchor={x,y};
    def.localAnchorA=b2Body_GetLocalPoint(def.bodyIdA,anchor);def.localAnchorB=b2Body_GetLocalPoint(def.bodyIdB,anchor);
    def.referenceAngle=b2Rot_GetAngle(b2Body_GetRotation(def.bodyIdB))-b2Rot_GetAngle(b2Body_GetRotation(def.bodyIdA));
    def.enableLimit=true;def.lowerAngle=-.65f;def.upperAngle=.65f;
    def.enableSpring=true;def.hertz=1.8f;def.dampingRatio=.7f;def.collideConnected=false;
    b2CreateRevoluteJoint(w->world,&def);
}
void ec_rope(ECWorld *w,int a,int b,float ax,float ay,float bx,float by) {
    b2DistanceJointDef def=b2DefaultDistanceJointDef();def.bodyIdA=w->bodies[a];def.bodyIdB=w->bodies[b];
    def.localAnchorA=b2Body_GetLocalPoint(def.bodyIdA,(b2Vec2){ax,ay});def.localAnchorB=b2Body_GetLocalPoint(def.bodyIdB,(b2Vec2){bx,by});
    // Zero spring stiffness leaves only the unilateral length limits:
    // slack cable must not push the bridge like a compressed rod.
    def.length=hypotf(bx-ax,by-ay);def.enableSpring=true;def.hertz=0;def.dampingRatio=0;
    def.enableLimit=true;def.minLength=.05f;def.maxLength=def.length+.12f;
    b2CreateDistanceJoint(w->world,&def);
}
void ec_teleport(ECWorld *w,int id,float x,float y) { b2Body_SetTransform(w->bodies[id],(b2Vec2){x,y},b2MakeRot(0)); b2Body_SetLinearVelocity(w->bodies[id],(b2Vec2){0,0}); b2Body_SetAngularVelocity(w->bodies[id],0); }
void ec_gravity(ECWorld *w,float gravity) { b2World_SetGravity(w->world,(b2Vec2){0,-gravity}); }
void ec_material(ECWorld *w,int id,float friction,float restitution) {
    b2ShapeId shapes[4];int n=b2Body_GetShapes(w->bodies[id],shapes,4);
    for(int i=0;i<n;i++) { b2Shape_SetFriction(shapes[i],friction);b2Shape_SetRestitution(shapes[i],restitution); }
}
void ec_density(ECWorld *w,int id,float density) {
    b2ShapeId shapes[4];int n=b2Body_GetShapes(w->bodies[id],shapes,4);
    for(int i=0;i<n;i++) b2Shape_SetDensity(shapes[i],density,true);
}
void ec_drive(ECWorld *w,int id,float input,float grip,bool swimming) {
    b2BodyId body=w->bodies[id];ECState s=ec_state(w,id);b2MassData m=b2Body_GetMassData(body);
    if(fabsf(input)>.01f) {
        float target=input*(swimming ? 2.7f : 3.4f);
        float force=fmaxf(-40,fminf(40,(target-s.vx)*18))*m.mass*grip;
        b2Body_ApplyForceToCenter(body,(b2Vec2){force,0},true);
        if(!swimming) b2Body_ApplyTorque(body,m.rotationalInertia*(-input*6-s.omega)*18*grip,true);
    } else if(!swimming && s.grounded) {
        float rightAngle=roundf(s.angle/1.5707963f)*1.5707963f;
        b2Body_ApplyTorque(body,m.rotationalInertia*((rightAngle-s.angle)*35-s.omega*8)*grip,true);
    }
}
int ec_slope(ECWorld *w,float start,float end,bool right) {
    if(w->count>=512) return -1;
    b2BodyDef bd=b2DefaultBodyDef();b2BodyId body=b2CreateBody(w->world,&bd);
    b2Vec2 vertices[4]={{start,right ? -3.9f : 0},{end,right ? 0 : -3.9f},{end,-4},{start,-4}};
    b2Hull hull=b2ComputeHull(vertices,4);b2Polygon poly=b2MakePolygon(&hull,0);
    b2ShapeDef sd=b2DefaultShapeDef();sd.material.friction=.7f;sd.material.restitution=.03f;
    b2CreatePolygonShape(body,&sd,&poly);
    int id=w->count++;w->bodies[id]=body;return id;
}
typedef struct { b2BodyId ignore; bool blocked; } ECQuery;
static bool ec_overlap(b2ShapeId shape,void *context) {
    ECQuery *q=context;
    if(B2_ID_EQUALS(b2Shape_GetBody(shape),q->ignore)) return true;
    q->blocked=true;return false;
}
bool ec_blocked(ECWorld *w,int id,float x,float y) {
    b2BodyId body=w->bodies[id];b2ShapeId shape;
    b2Body_GetShapes(body,&shape,1);b2Polygon poly=b2Shape_GetPolygon(shape);
    b2Transform transform={{x,y},b2Body_GetRotation(body)};
    b2Vec2 points[B2_MAX_POLYGON_VERTICES];
    for(int i=0;i<poly.count;i++) points[i]=b2TransformPoint(transform,poly.vertices[i]);
    b2ShapeProxy proxy=b2MakeProxy(points,poly.count,poly.radius);
    ECQuery q={body,false};
    b2World_OverlapShape(w->world,&proxy,b2DefaultQueryFilter(),ec_overlap,&q);
    return q.blocked;
}
bool ec_space_clear(ECWorld *w,float x,float y,float width,float height) {
    b2Vec2 points[4]={{x-width/2,y-height/2},{x+width/2,y-height/2},{x+width/2,y+height/2},{x-width/2,y+height/2}};
    b2ShapeProxy proxy=b2MakeProxy(points,4,0);
    ECQuery q={b2_nullBodyId,false};
    b2World_OverlapShape(w->world,&proxy,b2DefaultQueryFilter(),ec_overlap,&q);
    return !q.blocked;
}
